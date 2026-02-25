<script setup>
import { ref, computed, nextTick } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';
import { useKbd } from 'dashboard/composables/utils/useKbd';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const emit = defineEmits(['useDraft']);

const { t } = useI18n();
const store = useStore();
const currentChat = useMapGetter('getSelectedChat');

const conversationId = computed(() => currentChat.value?.id);
const showContextInput = ref(false);
const agentContext = ref('');
const contextInputRef = ref(null);

const useDraftShortcut = useKbd(['alt', '+', 'D']);
const refreshShortcut = useKbd(['alt', '+', 'R']);

const draft = computed(
  () => store.getters['voltAiDraft/getDraft'](conversationId.value)
);

const isLoading = computed(
  () => store.getters['voltAiDraft/isLoading'](conversationId.value)
);

const onUseDraft = () => {
  if (draft.value?.draftReply) {
    emit('useDraft', draft.value.draftReply);
  }
};

const onDismiss = () => {
  store.dispatch('voltAiDraft/clearDraft', conversationId.value);
};

const onGenerate = (context = null) => {
  showContextInput.value = false;
  agentContext.value = '';
  store.dispatch('voltAiDraft/generateDraft', {
    conversationId: conversationId.value,
    agentContext: context,
  });
};

const onRefreshClick = () => {
  showContextInput.value = true;
  nextTick(() => {
    contextInputRef.value?.focus();
  });
};

const onContextSubmit = () => {
  const ctx = agentContext.value.trim();
  onGenerate(ctx || null);
};

const onContextCancel = () => {
  showContextInput.value = false;
  agentContext.value = '';
};

const onContextKeydown = event => {
  if (event.key === 'Enter') {
    event.preventDefault();
    onContextSubmit();
  } else if (event.key === 'Escape') {
    onContextCancel();
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
      if (draft.value) {
        onRefreshClick();
      } else if (!isLoading.value) {
        onGenerate();
      }
    },
    allowOnFocusedInput: true,
  },
};

useKeyboardEvents(keyboardEvents);
</script>

<template>
  <div class="volt-ai-draft mx-2 mb-2 overflow-hidden">
    <!-- Context input (Spotlight-style) -->
    <div
      v-if="showContextInput"
      class="mb-2 rounded-xl border border-n-brand bg-n-solid-1 shadow-lg"
    >
      <div class="flex items-center gap-2 px-3 py-2">
        <span
          class="i-ph-sparkle-fill text-n-violet-9 text-sm flex-shrink-0"
        />
        <input
          ref="contextInputRef"
          v-model="agentContext"
          type="text"
          :placeholder="t('CONVERSATION.VOLT_AI.CONTEXT_PLACEHOLDER')"
          class="flex-1 bg-transparent text-sm text-n-slate-12 placeholder:text-n-slate-9 outline-none border-none"
          @keydown="onContextKeydown"
        />
        <div class="flex items-center gap-1 flex-shrink-0">
          <NextButton
            xs
            variant="faded"
            color="blue"
            icon="i-lucide-arrow-right"
            @click="onContextSubmit"
          />
          <NextButton
            xs
            ghost
            class="text-n-slate-11"
            icon="i-lucide-x"
            @click="onContextCancel"
          />
        </div>
      </div>
      <div class="px-3 pb-2">
        <span class="text-xs text-n-slate-9">
          {{ t('CONVERSATION.VOLT_AI.CONTEXT_HINT') }}
        </span>
      </div>
    </div>

    <!-- Loading state -->
    <div
      v-if="isLoading && !draft"
      class="flex items-center justify-center gap-2 py-2 px-4 rounded-xl border border-n-weak bg-n-solid-1"
    >
      <Spinner :size="16" class="text-n-brand" />
      <span class="text-xs text-n-slate-11">
        {{ t('CONVERSATION.VOLT_AI.GENERATING') }}
      </span>
    </div>

    <!-- Draft content -->
    <div
      v-else-if="draft"
      class="rounded-xl border border-n-weak bg-n-solid-1"
    >
      <div class="flex items-center justify-between px-4 pt-2 pb-1">
        <div class="flex items-center gap-1.5">
          <span class="i-ph-sparkle-fill text-n-violet-9 text-sm" />
          <span class="text-xs font-medium text-n-slate-11"> AI Draft </span>
        </div>
        <div class="flex items-center gap-1">
          <NextButton
            xs
            ghost
            class="text-n-slate-11"
            icon="i-lucide-refresh-cw"
            :label="`(${refreshShortcut})`"
            @click="onRefreshClick"
          />
          <NextButton
            xs
            ghost
            class="text-n-slate-11"
            icon="i-lucide-x"
            @click="onDismiss"
          />
        </div>
      </div>
      <div class="grid grid-cols-2 gap-3 px-4 pb-2">
        <div>
          <div class="text-xs font-medium text-n-slate-11 mb-1">
            {{ t('CONVERSATION.VOLT_AI.CONTEXT_TITLE') }}
          </div>
          <p
            class="text-sm text-n-slate-12 leading-relaxed whitespace-pre-line"
          >
            {{ draft.context }}
          </p>
        </div>
        <div>
          <div class="text-xs font-medium text-n-slate-11 mb-1">
            {{ t('CONVERSATION.VOLT_AI.DRAFT_TITLE') }}
          </div>
          <p
            class="text-sm text-n-slate-12 leading-relaxed whitespace-pre-line"
          >
            {{ draft.draftReply }}
          </p>
        </div>
      </div>
      <div class="flex justify-end px-4 pb-2">
        <NextButton
          xs
          variant="faded"
          color="blue"
          :label="`Use Draft (${useDraftShortcut})`"
          icon="i-lucide-arrow-down"
          @click="onUseDraft"
        />
      </div>
    </div>

    <!-- Generate button (when no draft and not loading) -->
    <div v-else class="flex justify-end">
      <NextButton
        xs
        ghost
        class="text-n-slate-11"
        icon="i-ph-sparkle-fill"
        :label="`AI Draft (${refreshShortcut})`"
        @click="() => onGenerate()"
      />
    </div>
  </div>
</template>
