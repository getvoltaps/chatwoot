<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import {
  createNewContact,
  createContactSearcher,
} from 'dashboard/components-next/NewConversation/helpers/composeConversationHelper';
import { appendSignature } from 'dashboard/helper/editorHelper';
import ConversationApi from 'dashboard/api/inbox/conversation';

import Button from 'dashboard/components-next/button/Button.vue';

const store = useStore();
const searchContacts = createContactSearcher();

const inboxesList = useMapGetter('inboxes/getInboxes');
const messageSignature = useMapGetter('getMessageSignature');

const emailInput = ref('');
const parsedEmails = ref([]);
const selectedInbox = ref(null);
const subject = ref('');
const messageContent = ref('');
const attachedFiles = ref([]);
const isSending = ref(false);
const sendProgress = ref(0);
const sendTotal = ref(0);
const sendErrors = ref([]);
const showInboxDropdown = ref(false);
const showFormatGuide = ref(false);
const fileInputRef = ref(null);
const messageTextarea = ref(null);

const emailInboxes = computed(() => {
  return inboxesList.value.filter(
    inbox => inbox.channel_type === 'Channel::Email'
  );
});

// Append signature when inbox is selected
watch(selectedInbox, inbox => {
  if (inbox && messageSignature.value && !messageContent.value) {
    messageContent.value = appendSignature(
      '',
      messageSignature.value,
      'Channel::Email'
    );
  }
});

const parseEmails = () => {
  const raw = emailInput.value;
  const emails = raw
    .split(/[,;\n]+/)
    .map(e => e.trim().toLowerCase())
    .filter(e => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e));

  const unique = [...new Set(emails)];
  parsedEmails.value = unique;
};

const removeEmail = index => {
  parsedEmails.value.splice(index, 1);
};

const clearAll = () => {
  parsedEmails.value = [];
  emailInput.value = '';
};

const canSend = computed(() => {
  return (
    parsedEmails.value.length > 0 &&
    selectedInbox.value &&
    subject.value.trim() &&
    messageContent.value.trim() &&
    !isSending.value
  );
});

const selectInbox = inbox => {
  selectedInbox.value = inbox;
  showInboxDropdown.value = false;
};

const onFileSelect = event => {
  const files = Array.from(event.target.files || []);
  attachedFiles.value = [...attachedFiles.value, ...files];
  event.target.value = '';
};

const removeFile = index => {
  attachedFiles.value.splice(index, 1);
};

const formatFileSize = bytes => {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
};

const wrapSelection = (before, after) => {
  const el = messageTextarea.value;
  if (!el) return;
  const start = el.selectionStart;
  const end = el.selectionEnd;
  const text = messageContent.value;
  const selected = text.substring(start, end);
  const replacement = `${before}${selected}${after || before}`;
  messageContent.value =
    text.substring(0, start) + replacement + text.substring(end);
  // Re-focus and select the inner text
  const cursorPos = start + before.length + selected.length + (after || before).length;
  requestAnimationFrame(() => {
    el.focus();
    el.setSelectionRange(cursorPos, cursorPos);
  });
};

const insertAtCursor = text => {
  const el = messageTextarea.value;
  if (!el) return;
  const start = el.selectionStart;
  const current = messageContent.value;
  messageContent.value =
    current.substring(0, start) + text + current.substring(start);
  const cursorPos = start + text.length;
  requestAnimationFrame(() => {
    el.focus();
    el.setSelectionRange(cursorPos, cursorPos);
  });
};

const insertLink = () => {
  const el = messageTextarea.value;
  if (!el) return;
  const start = el.selectionStart;
  const end = el.selectionEnd;
  const selected = messageContent.value.substring(start, end);
  const linkText = selected || 'link text';
  const replacement = `[${linkText}](https://url)`;
  messageContent.value =
    messageContent.value.substring(0, start) +
    replacement +
    messageContent.value.substring(end);
  // Select the URL part for easy replacement
  const urlStart = start + linkText.length + 3;
  const urlEnd = urlStart + 10;
  requestAnimationFrame(() => {
    el.focus();
    el.setSelectionRange(urlStart, urlEnd);
  });
};

const snoozeConversation = async conversationId => {
  await ConversationApi.toggleStatus({
    conversationId,
    status: 'snoozed',
    snoozedUntil: null,
  });
};

const sendBulkMail = async () => {
  if (!canSend.value) return;

  isSending.value = true;
  sendProgress.value = 0;
  sendTotal.value = parsedEmails.value.length;
  sendErrors.value = [];

  for (const email of parsedEmails.value) {
    try {
      let contact;
      const results = await searchContacts(email, { skipMinLength: true });
      const exactMatch = results.find(
        c => c.email?.toLowerCase() === email.toLowerCase()
      );

      if (exactMatch) {
        contact = exactMatch;
      } else {
        contact = await createNewContact(email);
      }

      const payload = new FormData();
      payload.append('inbox_id', selectedInbox.value.id);
      payload.append('contact_id', contact.id);
      payload.append('message[content]', messageContent.value);
      payload.append(
        'additional_attributes[mail_subject]',
        subject.value
      );

      attachedFiles.value.forEach(file => {
        payload.append('message[attachments][]', file);
      });

      const { data } = await ConversationApi.create(payload);

      await snoozeConversation(data.id);

      sendProgress.value += 1;
    } catch (error) {
      sendErrors.value.push(email);
      sendProgress.value += 1;
    }
  }

  isSending.value = false;

  const successCount = sendTotal.value - sendErrors.value.length;
  if (sendErrors.value.length > 0) {
    useAlert(
      `Sent ${successCount}/${sendTotal.value} emails. Failed: ${sendErrors.value.join(', ')}`
    );
  } else {
    useAlert(
      `All ${successCount} emails sent and snoozed until reply.`
    );
  }
};

onMounted(() => {
  store.dispatch('inboxes/get');
});
</script>

<template>
  <div
    class="flex flex-col flex-1 h-full overflow-auto bg-n-surface-1 p-6 gap-6"
  >
    <!-- Header -->
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-2xl font-bold text-n-slate-12">Bulk Mail</h1>
        <p class="text-sm text-n-slate-11 mt-1">
          Send individual emails to multiple recipients. Each email creates a
          separate conversation, snoozed until reply.
        </p>
      </div>
    </div>

    <div class="flex gap-6 flex-1 min-h-0">
      <!-- Left: Recipients -->
      <div
        class="flex flex-col w-1/2 bg-white dark:bg-n-solid-2 rounded-xl border border-n-strong p-4 gap-4"
      >
        <div class="flex items-center justify-between">
          <label class="text-sm font-semibold text-n-slate-12">
            Recipients
          </label>
          <span
            v-if="parsedEmails.length"
            class="text-xs text-n-slate-11"
          >
            {{ parsedEmails.length }} email{{
              parsedEmails.length !== 1 ? 's' : ''
            }}
          </span>
        </div>

        <textarea
          v-model="emailInput"
          placeholder="Paste email addresses here, separated by commas, semicolons, or new lines..."
          class="w-full h-32 p-3 text-sm border rounded-lg resize-none border-n-strong bg-n-alpha-1 text-n-slate-12 placeholder:text-n-slate-9 focus:outline-none focus:ring-2 focus:ring-n-brand"
          @input="parseEmails"
        />

        <div class="flex items-center gap-2">
          <Button
            v-if="parsedEmails.length"
            variant="ghost"
            color="slate"
            size="sm"
            label="Clear all"
            icon="i-lucide-trash-2"
            @click="clearAll"
          />
        </div>

        <!-- Parsed email chips -->
        <div
          v-if="parsedEmails.length"
          class="flex flex-wrap gap-1.5 overflow-y-auto flex-1 content-start"
        >
          <div
            v-for="(email, index) in parsedEmails"
            :key="email"
            class="flex items-center gap-1 px-2.5 py-1 text-xs rounded-lg bg-n-alpha-2 text-n-slate-12"
          >
            <span>{{ email }}</span>
            <span
              class="cursor-pointer i-lucide-x size-3 text-n-slate-9 hover:text-n-slate-12"
              @click="removeEmail(index)"
            />
          </div>
        </div>

        <div
          v-else
          class="flex items-center justify-center flex-1 text-sm text-n-slate-9"
        >
          No recipients added yet
        </div>
      </div>

      <!-- Right: Compose -->
      <div
        class="flex flex-col w-1/2 bg-white dark:bg-n-solid-2 rounded-xl border border-n-strong p-4 gap-4"
      >
        <!-- Inbox selector -->
        <div class="flex flex-col gap-1.5">
          <label class="text-sm font-semibold text-n-slate-12">
            Send from
          </label>
          <div class="relative">
            <button
              class="flex items-center w-full gap-2 px-3 py-2 text-sm border rounded-lg border-n-strong bg-n-alpha-1 text-n-slate-12 hover:bg-n-alpha-2"
              @click="showInboxDropdown = !showInboxDropdown"
            >
              <span
                v-if="selectedInbox"
                class="truncate"
              >
                {{ selectedInbox.name }}
                <span
                  v-if="selectedInbox.email"
                  class="text-n-slate-9"
                >
                  ({{ selectedInbox.email }})
                </span>
              </span>
              <span
                v-else
                class="text-n-slate-9"
              >
                Select an email inbox...
              </span>
              <span
                class="ml-auto i-lucide-chevron-down size-4 text-n-slate-9"
              />
            </button>
            <div
              v-if="showInboxDropdown"
              class="absolute z-10 w-full mt-1 overflow-y-auto border rounded-lg shadow-lg bg-white dark:bg-n-solid-3 border-n-strong max-h-48"
            >
              <button
                v-for="inbox in emailInboxes"
                :key="inbox.id"
                class="flex items-center w-full gap-2 px-3 py-2 text-sm text-left hover:bg-n-alpha-2 text-n-slate-12"
                @click="selectInbox(inbox)"
              >
                <span class="truncate">{{ inbox.name }}</span>
                <span
                  v-if="inbox.email"
                  class="text-n-slate-9 truncate"
                >
                  ({{ inbox.email }})
                </span>
              </button>
              <div
                v-if="emailInboxes.length === 0"
                class="px-3 py-2 text-sm text-n-slate-9"
              >
                No email inboxes available
              </div>
            </div>
          </div>
        </div>

        <!-- Subject -->
        <div class="flex flex-col gap-1.5">
          <label class="text-sm font-semibold text-n-slate-12">Subject</label>
          <input
            v-model="subject"
            type="text"
            placeholder="Email subject..."
            class="w-full px-3 py-2 text-sm border rounded-lg border-n-strong bg-n-alpha-1 text-n-slate-12 placeholder:text-n-slate-9 focus:outline-none focus:ring-2 focus:ring-n-brand"
          />
        </div>

        <!-- Message with formatting toolbar -->
        <div class="flex flex-col gap-1.5 flex-1">
          <div class="flex items-center justify-between">
            <label class="text-sm font-semibold text-n-slate-12">
              Message
            </label>
            <button
              class="text-xs text-n-slate-9 hover:text-n-slate-12 flex items-center gap-1"
              @click="showFormatGuide = !showFormatGuide"
            >
              <span class="i-lucide-help-circle size-3" />
              {{ showFormatGuide ? 'Hide' : 'Formatting guide' }}
            </button>
          </div>

          <!-- Formatting guide -->
          <div
            v-if="showFormatGuide"
            class="text-xs text-n-slate-11 bg-n-alpha-1 border border-n-weak rounded-lg p-3 space-y-1.5"
          >
            <div class="grid grid-cols-2 gap-x-4 gap-y-1">
              <span class="font-mono">**bold**</span>
              <span><strong>bold</strong></span>
              <span class="font-mono">*italic*</span>
              <span><em>italic</em></span>
              <span class="font-mono">[text](https://url)</span>
              <span>
                <a
                  href="#"
                  class="text-n-brand underline"
                  @click.prevent
                >text</a>
              </span>
              <span class="font-mono">- item</span>
              <span>Bullet list</span>
              <span class="font-mono">1. item</span>
              <span>Numbered list</span>
            </div>
          </div>

          <!-- Toolbar -->
          <div
            class="flex items-center gap-0.5 border border-n-strong border-b-0 rounded-t-lg bg-n-alpha-1 px-1 py-0.5"
          >
            <button
              class="p-1.5 rounded hover:bg-n-alpha-2 text-n-slate-11 hover:text-n-slate-12"
              title="Bold"
              @click="wrapSelection('**')"
            >
              <span class="i-lucide-bold size-3.5" />
            </button>
            <button
              class="p-1.5 rounded hover:bg-n-alpha-2 text-n-slate-11 hover:text-n-slate-12"
              title="Italic"
              @click="wrapSelection('*')"
            >
              <span class="i-lucide-italic size-3.5" />
            </button>
            <button
              class="p-1.5 rounded hover:bg-n-alpha-2 text-n-slate-11 hover:text-n-slate-12"
              title="Insert link"
              @click="insertLink"
            >
              <span class="i-lucide-link size-3.5" />
            </button>
            <div class="w-px h-4 bg-n-weak mx-1" />
            <button
              class="p-1.5 rounded hover:bg-n-alpha-2 text-n-slate-11 hover:text-n-slate-12"
              title="Bullet list"
              @click="insertAtCursor('\n- ')"
            >
              <span class="i-lucide-list size-3.5" />
            </button>
            <button
              class="p-1.5 rounded hover:bg-n-alpha-2 text-n-slate-11 hover:text-n-slate-12"
              title="Numbered list"
              @click="insertAtCursor('\n1. ')"
            >
              <span class="i-lucide-list-ordered size-3.5" />
            </button>
          </div>

          <textarea
            ref="messageTextarea"
            v-model="messageContent"
            placeholder="Write your message... supports **bold**, *italic*, [links](url)"
            class="w-full flex-1 p-3 text-sm border rounded-b-lg rounded-t-none resize-none border-n-strong bg-n-alpha-1 text-n-slate-12 placeholder:text-n-slate-9 focus:outline-none focus:ring-2 focus:ring-n-brand font-mono"
          />
        </div>

        <!-- Attachments -->
        <div class="flex flex-col gap-2">
          <div class="flex items-center gap-2">
            <input
              ref="fileInputRef"
              type="file"
              multiple
              class="hidden"
              @change="onFileSelect"
            />
            <Button
              variant="ghost"
              color="slate"
              size="sm"
              label="Attach files"
              icon="i-lucide-paperclip"
              @click="fileInputRef?.click()"
            />
          </div>
          <div
            v-if="attachedFiles.length"
            class="flex flex-wrap gap-2"
          >
            <div
              v-for="(file, index) in attachedFiles"
              :key="index"
              class="flex items-center gap-1.5 px-2.5 py-1 text-xs rounded-lg bg-n-alpha-2 text-n-slate-12"
            >
              <span class="i-lucide-file size-3 text-n-slate-9" />
              <span class="truncate max-w-[150px]">{{ file.name }}</span>
              <span class="text-n-slate-9">{{
                formatFileSize(file.size)
              }}</span>
              <span
                class="cursor-pointer i-lucide-x size-3 text-n-slate-9 hover:text-n-slate-12"
                @click="removeFile(index)"
              />
            </div>
          </div>
        </div>

        <!-- Progress bar -->
        <div
          v-if="isSending"
          class="flex flex-col gap-2"
        >
          <div
            class="flex items-center justify-between text-xs text-n-slate-11"
          >
            <span>Sending...</span>
            <span>{{ sendProgress }} / {{ sendTotal }}</span>
          </div>
          <div class="w-full h-2 rounded-full bg-n-alpha-2">
            <div
              class="h-2 rounded-full bg-n-brand transition-all duration-300"
              :style="{
                width: `${(sendProgress / sendTotal) * 100}%`,
              }"
            />
          </div>
        </div>

        <!-- Send button -->
        <div class="flex items-center justify-between pt-2">
          <span
            v-if="sendErrors.length"
            class="text-xs text-n-ruby-11"
          >
            {{ sendErrors.length }} failed
          </span>
          <span v-else />
          <Button
            :label="
              isSending
                ? `Sending ${sendProgress}/${sendTotal}...`
                : `Send to ${parsedEmails.length || 0} recipients`
            "
            color="primary"
            :disabled="!canSend"
            icon="i-lucide-send"
            @click="sendBulkMail"
          />
        </div>
      </div>
    </div>
  </div>
</template>
