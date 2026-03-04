import express from 'express';
import puppeteer from 'puppeteer-extra';
import StealthPlugin from 'puppeteer-extra-plugin-stealth';
import * as cheerio from 'cheerio';

puppeteer.use(StealthPlugin());

const PORT = process.env.VOLT_SIDECAR_PORT || 3100;
const BASE_URL = 'https://volunteer.getvolt.dk';
const EMAIL = process.env.CREWSTACK_USER;
const PASSWORD = process.env.CREWSTACK_PASS;

const CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes
const cache = new Map();

let browser = null;
let authPage = null;

// ─── Concurrency lock (one request at a time) ─────────────────────────────────

let inFlight = false;
const queue = [];

function withLock(fn) {
  return new Promise((resolve, reject) => {
    queue.push({ fn, resolve, reject });
    processQueue();
  });
}

async function processQueue() {
  if (inFlight || queue.length === 0) return;
  inFlight = true;
  const { fn, resolve, reject } = queue.shift();
  try { resolve(await fn()); }
  catch (err) { reject(err); }
  finally { inFlight = false; processQueue(); }
}

// ─── Browser lifecycle ────────────────────────────────────────────────────────

async function ensureBrowser() {
  if (browser && browser.connected) return;

  console.log('[sidecar] Launching browser...');
  browser = await puppeteer.launch({
    headless: true,
    executablePath: process.env.PUPPETEER_EXECUTABLE_PATH || undefined,
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage'],
  });
  authPage = null;

  browser.on('disconnected', () => {
    console.log('[sidecar] Browser disconnected, will relaunch on next request');
    browser = null;
    authPage = null;
  });
}

async function ensureLoggedIn() {
  await ensureBrowser();

  if (authPage) {
    try {
      const ok = await authPage.evaluate(async (url) => {
        const res = await fetch(`${url}/members/search.json?q=test`);
        return res.ok;
      }, BASE_URL);
      if (ok) return;
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

// ─── Find member by email ─────────────────────────────────────────────────────

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

// ─── Load member profile page ─────────────────────────────────────────────────

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

  // Scope to profile card only to avoid picking up shift status icons
  const status     = $('h1').closest('div').find('i.fa-circle').parent().text().trim() || null;
  const genderAge  = $('i.fa-female, i.fa-male, i.fa-genderless').parent().text().trim() || null;
  const birthday   = $('i.fa-birthday-cake').parent().text().trim() || null;
  const address    = $('i.fa-home').last().parent().text().trim() || null;
  const phone      = $('i.fa-phone').parent().text().trim() || null;
  const email      = $('i.fa-envelope-o').last().parent().text().trim() || null;

  // Custom member data fields
  const customFields = {};
  $('table.table-striped tr').each((_, row) => {
    const cells = $(row).find('td');
    if (cells.length >= 2) {
      const key = $(cells[0]).text().trim();
      const val = $(cells[1]).text().trim();
      if (key) customFields[key] = val;
    }
  });

  // Ticket info
  const ticket = {};
  $('table.table-condensed').first().find('tr').each((_, row) => {
    const cells = $(row).find('td');
    if (cells.length >= 2) {
      ticket[$(cells[0]).text().trim()] = $(cells[1]).text().trim();
    }
  });

  // Teams
  const teams = [];
  $('h3').filter((_, el) => $(el).text().trim() === 'Hold').each((_, el) => {
    $(el).nextAll('ul').first().find('a').each((_, a) => {
      teams.push({ name: $(a).text().trim(), url: $(a).attr('href') });
    });
  });

  // Shifts — parsed from the desktop table under #shifts-table
  const shifts = [];
  const shiftsTable = $('#shifts-table').next('.attendance-table-container').find('table.table-striped');
  if (shiftsTable.length) {
    shiftsTable.find('tbody tr').each((_, row) => {
      const cells = $(row).find('td').toArray();
      const statusIcon = $(cells[1]).find('i');
      shifts.push({
        status:       statusIcon.attr('data-original-title')?.trim() || null,
        statusClass:  statusIcon.attr('class') || null,
        team:         $(cells[2]).text().trim(),
        areaName:     $(cells[3]).text().trim(),
        shiftName:    $(cells[4]).text().trim(),
        shiftUrl:     $(cells[4]).find('a').attr('href') || null,
        description:  $(cells[5]).text().trim(),
        time:         $(cells[6]).text().trim(),
        meetingPlace: $(cells[7]).text().trim(),
      });
    });
  }

  return {
    id: memberId,
    profileUrl: `${BASE_URL}/members/${memberId}`,
    name, memberType, status, createdAt, genderAge, birthday,
    address, phone, email, customFields, ticket, teams, shifts,
  };
}

// ─── Get Betalt status from team page (DataTables — needs real navigation) ────

async function getTeamPaymentStatus(teamUrl, memberId) {
  const page = await browser.newPage();
  try {
    await page.goto(teamUrl, { waitUntil: 'networkidle2' });

    // Wait for DataTables to populate
    await page.waitForSelector('#DataTables_Table_1 tbody tr', { timeout: 15000 });

    // Check if member is already visible in the default 20-row view
    const visibleNow = await page.evaluate((memberId) => {
      return !!document.querySelector(`#DataTables_Table_1 a[href*="/members/${memberId}"]`);
    }, memberId);

    if (!visibleNow) {
      // Expand to 200 rows via the DataTables length dropdown
      await page.select('select[name="DataTables_Table_1_length"]', '200');
      await page.waitForFunction(
        (memberId) => !!document.querySelector(`#DataTables_Table_1 a[href*="/members/${memberId}"]`),
        { timeout: 10000 },
        memberId
      );
    }

    // Read Betalt cell from live DOM
    return await page.evaluate((memberId) => {
      const table = document.getElementById('DataTables_Table_1');
      if (!table) return { paid: null, tooltip: null, note: 'table not found' };

      const headers = Array.from(table.querySelectorAll('th')).map(th => th.innerText.trim());
      const betaltIdx = headers.indexOf('Betalt');
      if (betaltIdx === -1) return { paid: null, tooltip: null, note: 'Betalt column not found' };

      const row = Array.from(table.querySelectorAll('tbody tr'))
        .find(r => r.querySelector(`a[href*="/members/${memberId}"]`));
      if (!row) return { paid: null, tooltip: null, note: 'member row not found' };

      const cells = Array.from(row.querySelectorAll('td'));
      const betaltCell = cells[betaltIdx];
      const icon = betaltCell?.querySelector('i.fa-money');
      const tooltip = betaltCell?.querySelector('[data-original-title]')
        ?.getAttribute('data-original-title') || null;

      // fa-money text-navy = paid, fa-money text-danger = flagged/unpaid, no icon = null
      const paid = icon
        ? icon.classList.contains('text-navy')
        : null;

      return { paid, tooltip };
    }, memberId);
  } finally {
    await page.close();
  }
}

// ─── Main member fetch ────────────────────────────────────────────────────────

async function getMember(email) {
  await ensureLoggedIn();

  const result = await findMemberByEmail(authPage, email);
  if (!result) return null;

  const profile = await loadMemberProfile(authPage, result.value);

  console.log(`[sidecar] Loading payment status for ${profile.teams.length} team(s)...`);
  for (const team of profile.teams) {
    const teamUrl = team.url.startsWith('http') ? team.url : BASE_URL + team.url;
    console.log(`[sidecar]   → ${team.name} (${teamUrl})`);
    try {
      const payment = await getTeamPaymentStatus(teamUrl, result.value);
      team.paid = payment.paid;
      team.paymentTooltip = payment.tooltip;
    } catch (err) {
      console.error(`[sidecar] Failed to get payment for team ${team.name}:`, err.message);
      team.paid = null;
      team.paymentTooltip = null;
    }
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

  const cached = cache.get(email);
  if (cached && cached.expiresAt > Date.now()) {
    return res.json(cached.data);
  }

  try {
    const member = await withLock(() => getMember(email));
    if (!member) return res.status(404).json({ error: 'Member not found' });

    cache.set(email, { data: member, expiresAt: Date.now() + CACHE_TTL_MS });
    return res.json(member);
  } catch (err) {
    console.error('[sidecar] Error:', err.message);
    return res.status(500).json({ error: err.message });
  }
});

app.delete('/member', (req, res) => {
  const { email } = req.query;
  if (email) cache.delete(email);
  else cache.clear();
  res.json({ ok: true });
});

app.listen(PORT, () => {
  console.log(`[volt-member-sidecar] listening on http://localhost:${PORT}`);
});
