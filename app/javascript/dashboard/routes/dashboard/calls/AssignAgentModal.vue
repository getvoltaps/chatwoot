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

const allUsers = ref([]);
const isLoading = ref(true);
const selectedUserId = ref('');
const priority = ref(0);
const isSubmitting = ref(false);

const availableUsers = computed(() =>
  allUsers.value.filter(u => !props.excludeAgentIds.includes(u.id))
);

const selectedUser = computed(() =>
  allUsers.value.find(u => u.id === selectedUserId.value)
);

const canSubmit = computed(() => !!selectedUserId.value && !isSubmitting.value);

const fetchUsers = async () => {
  isLoading.value = true;
  try {
    const { data } = await VoltAPI.getTwilioAgents();
    allUsers.value = Array.isArray(data) ? data : [];
    if (availableUsers.value.length) {
      selectedUserId.value = availableUsers.value[0].id;
    }
  } catch {
    // silent
  } finally {
    isLoading.value = false;
  }
};

const onSubmit = () => {
  if (!canSubmit.value) return;
  isSubmitting.value = true;

  emit('submit', {
    internal_user_id: selectedUserId.value,
    user: selectedUser.value,
    priority: priority.value,
  });
};

const resetSubmitting = () => {
  isSubmitting.value = false;
};

defineExpose({ resetSubmitting });

onMounted(fetchUsers);
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header :header-title="t('CALLS.ASSIGN_AGENT.TITLE')" />
    <form class="flex flex-col gap-3 px-8 pb-8" @submit.prevent="onSubmit">
      <div>
        <label class="text-sm font-medium text-n-slate-12">
          {{ t('CALLS.ASSIGN_AGENT.SELECT_LABEL') }}
        </label>
        <div v-if="isLoading" class="text-sm text-n-slate-11 py-2">
          {{ t('CALLS.LOADING') }}
        </div>
        <select
          v-else
          v-model="selectedUserId"
          class="w-full mt-1 rounded-lg border border-n-weak bg-n-solid-2 px-3 py-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
        >
          <option v-if="!availableUsers.length" value="" disabled>
            {{ t('CALLS.ASSIGN_AGENT.NO_AGENTS') }}
          </option>
          <option
            v-for="user in availableUsers"
            :key="user.id"
            :value="user.id"
          >
            {{ user.name }} ({{ user.phonenumber }})
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
