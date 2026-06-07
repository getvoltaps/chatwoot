<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import { INBOX_TYPES } from 'dashboard/helper/inbox';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';

const props = defineProps({
  currentInboxId: {
    type: [Number, String],
    default: null,
  },
});

const emit = defineEmits(['submit']);

const { t } = useI18n();
const inboxes = useMapGetter('inboxes/getInboxes');

const dialogRef = ref(null);
const selectedInboxId = ref('');

const inboxOptions = computed(() =>
  inboxes.value
    .filter(
      inbox =>
        inbox.channel_type === INBOX_TYPES.EMAIL &&
        inbox.id !== Number(props.currentInboxId)
    )
    .map(inbox => ({
      value: inbox.id,
      label: inbox.email ? `${inbox.name} — ${inbox.email}` : inbox.name,
    }))
);

const isConfirmDisabled = computed(() => !selectedInboxId.value);

const open = () => {
  selectedInboxId.value = '';
  dialogRef.value?.open();
};

const close = () => {
  dialogRef.value?.close();
};

const handleConfirm = () => {
  if (!selectedInboxId.value) return;
  emit('submit', { inboxId: selectedInboxId.value });
  close();
};

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="lg"
    :title="t('CONVERSATION.MOVE_TO_INBOX.TITLE')"
    :description="t('CONVERSATION.MOVE_TO_INBOX.DESCRIPTION')"
    :confirm-button-label="t('CONVERSATION.MOVE_TO_INBOX.CONFIRM')"
    :cancel-button-label="t('CONVERSATION.MOVE_TO_INBOX.CANCEL')"
    :disable-confirm-button="isConfirmDisabled"
    @confirm="handleConfirm"
  >
    <div class="flex flex-col gap-2">
      <label class="mb-0.5 text-sm font-medium text-n-slate-12">
        {{ t('CONVERSATION.MOVE_TO_INBOX.SELECT_LABEL') }}
      </label>
      <ComboBox
        v-model="selectedInboxId"
        :options="inboxOptions"
        :placeholder="t('CONVERSATION.MOVE_TO_INBOX.SELECT_PLACEHOLDER')"
        class="w-full"
      />
    </div>
  </Dialog>
</template>
