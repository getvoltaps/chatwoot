<script setup>
import { ref, computed, nextTick } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';
import { emitter } from 'shared/helpers/mitt';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const { t } = useI18n();
const store = useStore();
const currentChat = useMapGetter('getSelectedChat');

const conversationId = computed(() => currentChat.value?.id);
const agentContext = ref('');
const contextInputRef = ref(null);

const draft = computed(
  () => store.getters['voltAiDraft/getDraft'](conversationId.value)
);

const isLoading = computed(
  () => store.getters['voltAiDraft/isLoading'](conversationId.value)
);

const translationDisclaimer =
  '*(This message has been translated using AI to help provide the best support experience)*';

const onUseDraft = () => {
  if (draft.value?.draftReply) {
    let text = draft.value.draftReply;
    if (draft.value.translated) {
      text = `${text}\n\n${translationDisclaimer}`;
    }
    emitter.emit(BUS_EVENTS.SET_EDITOR_CONTENT, text);
  }
};

const onGenerate = (context = null) => {
  agentContext.value = '';
  store.dispatch('voltAiDraft/generateDraft', {
    conversationId: conversationId.value,
    agentContext: context,
  });
};

const onContextSubmit = () => {
  const ctx = agentContext.value.trim();
  onGenerate(ctx || null);
};

const onContextKeydown = event => {
  if (event.key === 'Enter') {
    event.preventDefault();
    onContextSubmit();
  }
};

const keyboardEvents = {
  'Alt+KeyD': {
    action: e => {
      e.preventDefault();
      if (draft.value?.draftReply) {
        onUseDraft();
      }
    },
    allowOnFocusedInput: true,
  },
  'Alt+KeyR': {
    action: e => {
      e.preventDefault();
      if (!isLoading.value) {
        onGenerate();
      }
    },
    allowOnFocusedInput: true,
  },
};

useKeyboardEvents(keyboardEvents);
</script>

<template>
  <div class="flex flex-col h-full">
    <!-- Header -->
    <div
      class="flex items-center gap-2 px-4 py-3 border-b border-n-weak"
    >
      <span class="i-ph-sparkle-fill text-n-violet-9 text-base" />
      <span class="text-sm font-semibold text-n-slate-12">AI Draft</span>
    </div>

    <div class="flex-1 overflow-y-auto p-4 flex flex-col gap-4">
      <!-- Loading state -->
      <div
        v-if="isLoading && !draft"
        class="flex items-center justify-center gap-2 py-8"
      >
        <Spinner :size="20" class="text-n-violet-9" />
        <span class="text-sm text-n-slate-11">Generating draft...</span>
      </div>

      <!-- No draft yet -->
      <div
        v-else-if="!draft"
        class="flex flex-col items-center justify-center gap-3 py-8 text-center"
      >
        <span
          class="i-ph-sparkle text-n-slate-9 size-8"
        />
        <p class="text-sm text-n-slate-11">
          Generate an AI draft based on the conversation
        </p>
        <NextButton
          sm
          variant="faded"
          color="blue"
          label="Generate Draft (Alt+R)"
          icon="i-ph-sparkle-fill"
          @click="() => onGenerate()"
        />
      </div>

      <!-- Draft content -->
      <template v-else>
        <!-- Context -->
        <div class="flex flex-col gap-1.5">
          <div class="text-xs font-semibold text-n-slate-11 uppercase tracking-wide">
            Context
          </div>
          <div
            class="text-sm text-n-slate-12 leading-relaxed whitespace-pre-line bg-n-alpha-1 rounded-lg p-3 border border-n-weak"
          >
            {{ draft.context }}
          </div>
        </div>

        <!-- Suggested Reply -->
        <div class="flex flex-col gap-1.5">
          <div class="text-xs font-semibold text-n-slate-11 uppercase tracking-wide">
            Suggested Reply
          </div>
          <div
            class="text-sm text-n-slate-12 leading-relaxed whitespace-pre-line bg-n-alpha-1 rounded-lg p-3 border border-n-weak"
          >
            {{ draft.draftReply }}
          </div>
          <p
            v-if="draft.translated"
            class="text-xs text-n-slate-9 italic"
          >
            Translated with AI — disclaimer will be added
          </p>
        </div>

        <!-- Use Draft button -->
        <NextButton
          sm
          variant="faded"
          color="blue"
          label="Use Draft (Alt+D)"
          icon="i-lucide-arrow-down"
          class="self-end"
          @click="onUseDraft"
        />
      </template>

      <!-- Improve / Regenerate input -->
      <div class="flex flex-col gap-1.5 mt-auto">
        <div class="text-xs font-semibold text-n-slate-11 uppercase tracking-wide">
          {{ draft ? 'Improve Draft' : 'Add Context' }}
        </div>
        <div class="flex items-center gap-2">
          <input
            ref="contextInputRef"
            v-model="agentContext"
            type="text"
            placeholder="e.g. Customer is VIP, offer discount..."
            class="flex-1 px-3 py-2 text-sm border rounded-lg border-n-strong bg-n-alpha-1 text-n-slate-12 placeholder:text-n-slate-9 focus:outline-none focus:ring-2 focus:ring-n-brand"
            @keydown="onContextKeydown"
          />
          <NextButton
            sm
            variant="faded"
            color="blue"
            icon="i-lucide-refresh-cw"
            :disabled="isLoading"
            @click="onContextSubmit"
          />
        </div>
      </div>
    </div>
  </div>
</template>
