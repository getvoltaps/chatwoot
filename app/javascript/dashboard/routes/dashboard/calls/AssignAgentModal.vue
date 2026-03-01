<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import VoltAPI from 'dashboard/api/integrations/volt';

const props = defineProps({
  excludeAgentIds: { type: Array, default: () => [] },
});

const emit = defineEmits(['submit', 'close']);

const { t } = useI18n();

const allAgents = ref([]);
const isLoadingAgents = ref(true);
const selectedAgentId = ref('');
const priority = ref(0);
const isSubmitting = ref(false);

const availableAgents = computed(() =>
  allAgents.value.filter(a => !props.excludeAgentIds.includes(a.id))
);

const selectedAgent = computed(() =>
  allAgents.value.find(a => a.id === selectedAgentId.value)
);

const canSubmit = computed(() => !!selectedAgentId.value && !isSubmitting.value);

const fetchAgents = async () => {
  isLoadingAgents.value = true;
  try {
    const { data } = await VoltAPI.getTwilioAgents();
    allAgents.value = Array.isArray(data) ? data : [];
    if (availableAgents.value.length) {
      selectedAgentId.value = availableAgents.value[0].id;
    }
  } catch {
    // silent
  } finally {
    isLoadingAgents.value = false;
  }
};

const onSubmit = () => {
  if (!canSubmit.value) return;
  isSubmitting.value = true;

  emit('submit', {
    agent_id: selectedAgentId.value,
    agent: selectedAgent.value,
    priority: priority.value,
  });
};

const resetSubmitting = () => {
  isSubmitting.value = false;
};

defineExpose({ resetSubmitting });

onMounted(fetchAgents);
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header :header-title="t('CALLS.ASSIGN_AGENT.TITLE')" />
    <form class="flex flex-col gap-3 px-8 pb-8" @submit.prevent="onSubmit">
      <div>
        <label class="text-sm font-medium text-n-slate-12">
          {{ t('CALLS.ASSIGN_AGENT.SELECT_LABEL') }}
        </label>
        <div v-if="isLoadingAgents" class="text-sm text-n-slate-11 py-2">
          {{ t('CALLS.LOADING') }}
        </div>
        <select
          v-else
          v-model="selectedAgentId"
          class="w-full mt-1 rounded-lg border border-n-weak bg-n-solid-2 px-3 py-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
        >
          <option v-if="!availableAgents.length" value="" disabled>
            {{ t('CALLS.ASSIGN_AGENT.NO_AGENTS') }}
          </option>
          <option
            v-for="agent in availableAgents"
            :key="agent.id"
            :value="agent.id"
          >
            {{ agent.agent_name || agent.agent_phone }} ({{ agent.agent_phone }})
          </option>
        </select>
      </div>

      <div>
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
          :label="t('CALLS.ASSIGN_AGENT.SUBMIT')"
          :disabled="!canSubmit"
          :is-loading="isSubmitting"
        />
      </div>
    </form>
  </div>
</template>
