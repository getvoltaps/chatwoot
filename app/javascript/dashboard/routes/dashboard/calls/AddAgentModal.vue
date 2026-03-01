<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  agent: { type: Object, default: null },
  identityOnly: { type: Boolean, default: false },
});

const emit = defineEmits(['submit', 'close']);

const { t } = useI18n();

const isEdit = computed(() => !!props.agent);

const agentPhone = ref('');
const agentName = ref('');
const priority = ref(0);
const showCallerId = ref(true);
const isActive = ref(true);
const isSubmitting = ref(false);

watch(
  () => props.agent,
  val => {
    if (val) {
      agentPhone.value = val.agent_phone || '';
      agentName.value = val.agent_name || '';
      priority.value = val.priority ?? 0;
      showCallerId.value = val.show_caller_id === 1;
      isActive.value = (val.is_active ?? val.agent_active) === 1;
    } else {
      agentPhone.value = '';
      agentName.value = '';
      priority.value = 0;
      showCallerId.value = true;
      isActive.value = true;
    }
  },
  { immediate: true }
);

const isPhoneValid = computed(() => /^\+\d{6,15}$/.test(agentPhone.value));

const onSubmit = () => {
  if (!isPhoneValid.value) return;
  isSubmitting.value = true;

  const data = {
    agent_phone: agentPhone.value,
    agent_name: agentName.value || undefined,
    priority: priority.value,
    show_caller_id: showCallerId.value ? 1 : 0,
    is_active: isActive.value ? 1 : 0,
  };

  emit('submit', data);
};

const resetSubmitting = () => {
  isSubmitting.value = false;
};

defineExpose({ resetSubmitting });
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header
      :header-title="
        isEdit ? t('CALLS.ADD_AGENT.EDIT_TITLE') : t('CALLS.ADD_AGENT.TITLE')
      "
    />
    <form class="flex flex-col gap-3 px-8 pb-8" @submit.prevent="onSubmit">
      <div>
        <label class="text-sm font-medium text-n-slate-12">
          {{ t('CALLS.ADD_AGENT.PHONE.LABEL') }}
        </label>
        <input
          v-model="agentPhone"
          type="tel"
          :placeholder="t('CALLS.ADD_AGENT.PHONE.PLACEHOLDER')"
          class="w-full mt-1 rounded-lg border border-n-weak bg-n-solid-2 px-3 py-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          :disabled="isEdit"
        />
        <span class="text-xs text-n-slate-9 mt-1">
          {{ t('CALLS.ADD_AGENT.PHONE.HELP') }}
        </span>
      </div>

      <div>
        <label class="text-sm font-medium text-n-slate-12">
          {{ t('CALLS.ADD_AGENT.NAME.LABEL') }}
        </label>
        <input
          v-model="agentName"
          type="text"
          :placeholder="t('CALLS.ADD_AGENT.NAME.PLACEHOLDER')"
          class="w-full mt-1 rounded-lg border border-n-weak bg-n-solid-2 px-3 py-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
        />
      </div>

      <div v-if="!identityOnly">
        <label class="text-sm font-medium text-n-slate-12">
          {{ t('CALLS.ADD_AGENT.PRIORITY.LABEL') }}
        </label>
        <input
          v-model.number="priority"
          type="number"
          min="0"
          class="w-full mt-1 rounded-lg border border-n-weak bg-n-solid-2 px-3 py-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
        />
        <span class="text-xs text-n-slate-9 mt-1">
          {{ t('CALLS.ADD_AGENT.PRIORITY.HELP') }}
        </span>
      </div>

      <div class="flex items-center gap-2">
        <input
          id="show-caller-id"
          v-model="showCallerId"
          type="checkbox"
          class="size-4"
        />
        <div>
          <label for="show-caller-id" class="text-sm text-n-slate-12">
            {{ t('CALLS.ADD_AGENT.SHOW_CALLER_ID.LABEL') }}
          </label>
          <p class="text-xs text-n-slate-9">
            {{ t('CALLS.ADD_AGENT.SHOW_CALLER_ID.HELP') }}
          </p>
        </div>
      </div>

      <div class="flex items-center gap-2">
        <input
          id="is-active"
          v-model="isActive"
          type="checkbox"
          class="size-4"
        />
        <div>
          <label for="is-active" class="text-sm text-n-slate-12">
            {{ t('CALLS.ADD_AGENT.IS_ACTIVE.LABEL') }}
          </label>
          <p class="text-xs text-n-slate-9">
            {{ t('CALLS.ADD_AGENT.IS_ACTIVE.HELP') }}
          </p>
        </div>
      </div>

      <div class="flex items-center justify-end gap-2 pt-2">
        <Button
          faded
          slate
          type="reset"
          :label="t('CALLS.ADD_AGENT.CANCEL')"
          @click.prevent="$emit('close')"
        />
        <Button
          type="submit"
          :label="
            isEdit
              ? t('CALLS.ADD_AGENT.UPDATE')
              : t('CALLS.ADD_AGENT.SUBMIT')
          "
          :disabled="!isPhoneValid || isSubmitting"
          :is-loading="isSubmitting"
        />
      </div>
    </form>
  </div>
</template>
