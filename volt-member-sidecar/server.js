import express from 'express';
import puppeteer from 'puppeteer-extra';
import StealthPlugin from 'puppeteer-extra-plugin-stealth';
import * as cheerio from 'cheerio';

puppeteer.use(StealthPlugin());

const PORT = process.env.VOLT_SIDECAR_PORT || 3100;
const BASE_URL = 'https://volunteer.getvolt.dk';
const EMAIL = process.env.CREWSTACK_USER;
const PASSWORD = process.env.CREWSTACK_PASS;

// Simple TTL cache: email -> { data, expiresAt }
const CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes
const cache = new Map();

// Shared browser + authenticated page
let browser = null;
let authPage = null;

// ─── Browser lifecycle ────────────────────────────────────────────────────────

async function ensureBrowser() {
  if (browser && browser.connected) return;

  console.log('[sidecar] Launching browser...');
  const launchOptions = {
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage'],
  };
  if (process.env.PUPPETEER_EXECUTABLE_PATH) {
    launchOptions.executablePath = process.env.PUPPETEER_EXECUTABLE_PATH;
  }
  browser = await puppeteer.launch(launchOptions);
  authPage = null; // force re-auth
}

async function ensureLoggedIn() {
  await ensureBrowser();

  // Test if session is still valid
  if (authPage) {
    try {
      const testHtml = await authPage.evaluate(async (url) => {
        const res = await fetch(`${url}/members/search.json?q=test`);
        return res.ok ? 'ok' : 'fail';
      }, BASE_URL);
      if (testHtml === 'ok') return;
    } catch {
      // session expired or page crashed
    }
  }

  console.log('[sidecar] Logging in...');
  const page = await browser.newPage();
  await page.goto(`${BASE_URL}/users/sign_in`, { waitUntil: 'networkidle2' });
  await page.type('input[type="email"]', EMAIL);
  await page.type('input[type="password"]', PASSWORD);
  await Promise.all([
    page.waitForNavigation({ waitUntil: 'networkidle2' }),
    page.click('input[type="submit"]'),
  ]);

  if (page.url().includes('sign_in')) {
    throw new Error('Login failed — still on sign-in page');
  }

  console.log('[sidecar] Logged in.');
  authPage = page;
}

// ─── Scraping logic (same as volt-member.js) ─────────────────────────────────

async function findMemberByEmail(page, email) {
  const results = await page.evaluate(async (baseUrl, email) => {
    const res = await fetch(`${baseUrl}/members/search.json?q=${encodeURIComponent(email)}`);
    if (!res.ok) throw new Error(`Search failed: ${res.status}`);
    return res.json();
  }, BASE_URL, email);

  if (!results.length) return null;

  const exact = results.find(r => r.text.toLowerCase() === email.toLowerCase());
  return exact || results[0];
}

async function loadMemberProfile(page, memberId) {
  const html = await page.evaluate(async (baseUrl, id) => {
    const res = await fetch(`${baseUrl}/members/${id}`);
    if (!res.ok) throw new Error(`Failed to load profile: ${res.status}`);
    return res.text();
  }, BASE_URL, memberId);

  const $ = cheerio.load(html);

  const name       = $('h1').first().text().trim();
  const memberType = $('h3').first().text().trim();
  const createdAt  = $('h1').closest('div').find('p').first().text().replace('Oprettet', '').trim();
  const status     = $('i.fa-circle').parent().text().trim() || null;
  const genderAge  = $('i.fa-female, i.fa-male, i.fa-genderless').parent().text().trim() || null;
  const birthday   = $('i.fa-birthday-cake').parent().text().trim() || null;
  const address    = $('i.fa-home').last().parent().text().trim() || null;
  const phone      = $('i.fa-phone').parent().text().trim() || null;
  const email      = $('i.fa-envelope-o').last().parent().text().trim() || null;

  const customFields = {};
  $('table.table-striped tr').each((_, row) => {
    const cells = $(row).find('td');
    if (cells.length >= 2) {
      const key = $(cells[0]).text().trim();
      const val = $(cells[1]).text().trim();
      if (key) customFields[key] = val;
    }
  });

  const ticket = {};
  $('table.table-condensed').first().find('tr').each((_, row) => {
    const cells = $(row).find('td');
    if (cells.length >= 2) {
      ticket[$(cells[0]).text().trim()] = $(cells[1]).text().trim();
    }
  });

  const teams = [];
  $('h3').filter((_, el) => $(el).text().includes('Hold')).each((_, el) => {
    $(el).nextAll('ul').first().find('a').each((_, a) => {
      teams.push({ name: $(a).text().trim(), url: $(a).attr('href') });
    });
  });

  return {
    id: memberId,
    profileUrl: `${BASE_URL}/members/${memberId}`,
    name, memberType, status, createdAt, genderAge, birthday,
    address, phone, email, customFields, ticket, teams,
  };
}

async function getTeamPaymentStatus(page, teamUrl, memberId) {
  const html = await page.evaluate(async (url) => {
    const res = await fetch(url);
    if (!res.ok) throw new Error(`Failed to load team: ${res.status}`);
    return res.text();
  }, teamUrl);

  const $ = cheerio.load(html);

  let targetTable = null;
  $('table').each((_, table) => {
    if ($(table).find('th').toArray().some(th => $(th).text().trim() === 'Betalt')) {
      targetTable = $(table);
    }
  });

  if (!targetTable) return { paid: null, tooltip: null };

  const headers = targetTable.find('th').toArray().map(th => $(th).text().trim());
  const betaltIdx = headers.indexOf('Betalt');

  let betaltResult = { paid: false, tooltip: null };
  targetTable.find('tbody tr').each((_, row) => {
    const memberLink = $(row).find(`a[href*="/members/${memberId}"]`);
    if (memberLink.length) {
      const cells = $(row).find('td').toArray();
      const betaltCell = $(cells[betaltIdx]);
      const icon = betaltCell.find('i');
      const tooltip = betaltCell.find('[data-original-title]').attr('data-original-title') || null;
      if (icon.length && icon.hasClass('fa-money')) {
        betaltResult = { paid: true, tooltip };
      }
    }
  });

  return betaltResult;
}

async function getMember(email) {
  await ensureLoggedIn();

  const result = await findMemberByEmail(authPage, email);
  if (!result) return null;

  const profile = await loadMemberProfile(authPage, result.value);

  for (const team of profile.teams) {
    const teamUrl = team.url.startsWith('http') ? team.url : BASE_URL + team.url;
    const payment = await getTeamPaymentStatus(authPage, teamUrl, result.value);
    team.paid = payment.paid;
    team.paymentTooltip = payment.tooltip;
  }

  return profile;
}

// ─── Express server ───────────────────────────────────────────────────────────

const app = express();

app.get('/health', (_req, res) => {
  res.json({ status: 'ok', browserConnected: browser?.connected || false });
});

app.get('/member', async (req, res) => {
  const { email } = req.query;
  if (!email) return res.status(400).json({ error: 'email query param required' });

  // Check cache
  const cached = cache.get(email);
  if (cached && cached.expiresAt > Date.now()) {
    return res.json(cached.data);
  }

  try {
    const member = await getMember(email);
    if (!member) return res.status(404).json({ error: 'Member not found' });

    cache.set(email, { data: member, expiresAt: Date.now() + CACHE_TTL_MS });
    return res.json(member);
  } catch (err) {
    console.error('[sidecar] Error:', err.message);
    return res.status(500).json({ error: err.message });
  }
});

app.listen(PORT, () => {
  console.log(`[volt-member-sidecar] listening on http://localhost:${PORT}`);
});
