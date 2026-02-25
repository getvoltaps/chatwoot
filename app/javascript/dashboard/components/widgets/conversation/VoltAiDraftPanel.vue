<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const emit = defineEmits(['useDraft']);

const { t } = useI18n();
const store = useStore();
const currentChat = useMapGetter('getSelectedChat');

const conversationId = computed(() => currentChat.value?.id);

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

const onGenerate = () => {
  store.dispatch('voltAiDraft/generateDraft', conversationId.value);
};
</script>

<template>
  <div class="volt-ai-draft mx-2 mb-2 overflow-hidden">
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
    <div v-else-if="draft" class="rounded-xl border border-n-weak bg-n-solid-1">
      <div class="flex items-center justify-between px-4 pt-2 pb-1">
        <div class="flex items-center gap-1.5">
          <span class="i-ph-sparkle-fill text-n-violet-9 text-sm" />
          <span class="text-xs font-medium text-n-slate-11">
            AI Draft
          </span>
        </div>
        <div class="flex items-center gap-1">
          <NextButton
            xs
            ghost
            class="text-n-slate-11"
            icon="i-lucide-refresh-cw"
            @click="onGenerate"
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
          <p class="text-sm text-n-slate-12 leading-relaxed whitespace-pre-line">
            {{ draft.context }}
          </p>
        </div>
        <div>
          <div class="text-xs font-medium text-n-slate-11 mb-1">
            {{ t('CONVERSATION.VOLT_AI.DRAFT_TITLE') }}
          </div>
          <p class="text-sm text-n-slate-12 leading-relaxed whitespace-pre-line">
            {{ draft.draftReply }}
          </p>
        </div>
      </div>
      <div class="flex justify-end px-4 pb-2">
        <NextButton
          xs
          variant="faded"
          color="blue"
          label="Use Draft"
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
        label="AI Draft"
        @click="onGenerate"
      />
    </div>
  </div>
</template>
