<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import VoltAPI from 'dashboard/api/integrations/volt';

import BaseSettingsHeader from '../settings/components/BaseSettingsHeader.vue';
import SettingsLayout from '../settings/SettingsLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import {
  BaseTable,
  BaseTableRow,
  BaseTableCell,
} from 'dashboard/components-next/table';
import AddAgentModal from './AddAgentModal.vue';

const { t } = useI18n();

const isLoading = ref(true);
const agents = ref([]);
const editions = ref([]);
const expandedAgentId = ref(null);

// Agent modals
const showAddModal = ref(false);
const showEditModal = ref(false);
const showDeleteConfirm = ref(false);
const selectedAgent = ref(null);
const addModalRef = ref(null);
const editModalRef = ref(null);

// Assignment form
const showAssignForm = ref(false);
const assignType = ref('queue');
const assignQueueName = ref('support');
const assignEditionId = ref('');
const assignPriority = ref(0);

const QUEUE_OPTIONS = ['support', 'hr', 'sales'];

const tableHeaders = computed(() => [
  t('CALLS.AGENTS.NAME'),
  t('CALLS.AGENTS.PHONE'),
  t('CALLS.AGENTS.CALLER_ID'),
  t('CALLS.AGENTS.ACTIVE'),
  t('CALLS.AGENTS.ASSIGNMENTS'),
  t('CALLS.AGENTS.ACTIONS'),
]);

const fetchData = async () => {
  isLoading.value = true;
  try {
    const [agentsRes, editionsRes] = await Promise.all([
      VoltAPI.getTwilioAgents(),
      VoltAPI.getTwilioEditions(),
    ]);
    agents.value = Array.isArray(agentsRes.data) ? agentsRes.data : [];
    editions.value = Array.isArray(editionsRes.data) ? editionsRes.data : [];
  } catch {
    useAlert(t('CALLS.API.ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const refreshAgents = async () => {
  try {
    const { data } = await VoltAPI.getTwilioAgents();
    agents.value = Array.isArray(data) ? data : [];
  } catch {
    // silent
  }
};

const toggleExpand = agent => {
  if (expandedAgentId.value === agent.id) {
    expandedAgentId.value = null;
    showAssignForm.value = false;
  } else {
    expandedAgentId.value = agent.id;
    showAssignForm.value = false;
  }
};

const assignmentLabel = assignment => {
  if (assignment.queue_name) {
    return assignment.queue_name;
  }
  return assignment.edition_name || assignment.edition_id;
};

// Agent CRUD
const openAddModal = () => {
  selectedAgent.value = null;
  showAddModal.value = true;
};

const closeAddModal = () => {
  showAddModal.value = false;
};

const onAddAgent = async agentData => {
  try {
    await VoltAPI.addTwilioAgent({
      agent_phone: agentData.agent_phone,
      agent_name: agentData.agent_name,
      show_caller_id: agentData.show_caller_id,
      is_active: agentData.is_active,
    });
    useAlert(t('CALLS.API.AGENT_ADDED'));
    closeAddModal();
    await refreshAgents();
  } catch {
    useAlert(t('CALLS.API.ERROR'));
    addModalRef.value?.resetSubmitting();
  }
};

const openEditModal = agent => {
  selectedAgent.value = agent;
  showEditModal.value = true;
};

const closeEditModal = () => {
  showEditModal.value = false;
  selectedAgent.value = null;
};

const onEditAgent = async agentData => {
  try {
    await VoltAPI.updateTwilioAgent(selectedAgent.value.id, {
      agent_phone: agentData.agent_phone,
      agent_name: agentData.agent_name,
      show_caller_id: agentData.show_caller_id,
      is_active: agentData.is_active,
    });
    useAlert(t('CALLS.API.AGENT_UPDATED'));
    closeEditModal();
    await refreshAgents();
  } catch {
    useAlert(t('CALLS.API.ERROR'));
    editModalRef.value?.resetSubmitting();
  }
};

const openDeleteConfirm = agent => {
  selectedAgent.value = agent;
  showDeleteConfirm.value = true;
};

const closeDeleteConfirm = () => {
  showDeleteConfirm.value = false;
  selectedAgent.value = null;
};

const onDeleteAgent = async () => {
  try {
    await VoltAPI.deleteTwilioAgent(selectedAgent.value.id);
    useAlert(t('CALLS.API.AGENT_DELETED'));
    closeDeleteConfirm();
    if (expandedAgentId.value === selectedAgent.value.id) {
      expandedAgentId.value = null;
    }
    await refreshAgents();
  } catch {
    useAlert(t('CALLS.API.ERROR'));
  }
};

// Assignment CRUD
const openAssignForm = () => {
  assignType.value = 'queue';
  assignQueueName.value = 'support';
  assignEditionId.value = editions.value[0]?.id || '';
  assignPriority.value = 0;
  showAssignForm.value = true;
};

const cancelAssignForm = () => {
  showAssignForm.value = false;
};

const addAssignment = async () => {
  const agentId = expandedAgentId.value;
  const data = { priority: assignPriority.value, is_active: 1 };
  if (assignType.value === 'queue') {
    data.queue_name = assignQueueName.value;
  } else {
    data.edition_id = assignEditionId.value;
  }
  try {
    await VoltAPI.addAgentAssignment(agentId, data);
    useAlert(t('CALLS.API.ASSIGNMENT_ADDED'));
    showAssignForm.value = false;
    await refreshAgents();
  } catch {
    useAlert(t('CALLS.API.ERROR'));
  }
};

const removeAssignment = async (agentId, assignmentId) => {
  try {
    await VoltAPI.deleteAgentAssignment(agentId, assignmentId);
    useAlert(t('CALLS.API.ASSIGNMENT_REMOVED'));
    await refreshAgents();
  } catch {
    useAlert(t('CALLS.API.ERROR'));
  }
};

onMounted(fetchData);
</script>

<template>
  <SettingsLayout
    :is-loading="isLoading"
    :loading-message="t('CALLS.LOADING')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="t('CALLS.AGENTS.HEADER')"
        :description="t('CALLS.AGENTS.DESCRIPTION')"
      >
        <template #actions>
          <Button
            :label="t('CALLS.AGENTS.ADD')"
            size="sm"
            icon="i-lucide-plus"
            @click="openAddModal"
          />
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <BaseTable
        v-if="agents.length"
        :headers="tableHeaders"
        :items="agents"
      >
        <template #row="{ items }">
          <template v-for="agent in items" :key="agent.id">
            <BaseTableRow
              :item="agent"
              class="cursor-pointer hover:bg-n-alpha-1"
              @click="toggleExpand(agent)"
            >
              <template #default>
                <BaseTableCell>
                  <span class="text-body-main text-n-slate-12 font-medium">
                    {{ agent.agent_name || '—' }}
                  </span>
                </BaseTableCell>
                <BaseTableCell>
                  <span class="text-body-main text-n-slate-11">
                    {{ agent.agent_phone }}
                  </span>
                </BaseTableCell>
                <BaseTableCell>
                  <span
                    class="inline-flex items-center rounded-full px-2 py-0.5 text-xs"
                    :class="
                      agent.show_caller_id
                        ? 'bg-n-teal-2 text-n-teal-11'
                        : 'bg-n-alpha-2 text-n-slate-11'
                    "
                  >
                    {{ agent.show_caller_id ? 'Yes' : 'No' }}
                  </span>
                </BaseTableCell>
                <BaseTableCell>
                  <span
                    class="inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-xs"
                    :class="
                      agent.is_active
                        ? 'bg-n-teal-2 text-n-teal-11'
                        : 'bg-n-alpha-2 text-n-slate-11'
                    "
                  >
                    {{ agent.is_active ? 'Active' : 'Inactive' }}
                  </span>
                </BaseTableCell>
                <BaseTableCell>
                  <div class="flex flex-wrap gap-1">
                    <span
                      v-for="asgn in agent.assignments"
                      :key="asgn.id"
                      class="inline-flex items-center rounded-full px-2 py-0.5 text-xs capitalize"
                      :class="
                        asgn.is_active
                          ? 'bg-n-blue-2 text-n-blue-11'
                          : 'bg-n-alpha-2 text-n-slate-11'
                      "
                    >
                      {{ assignmentLabel(asgn) }}
                    </span>
                    <span
                      v-if="!agent.assignments.length"
                      class="text-xs text-n-slate-9"
                    >
                      {{ t('CALLS.AGENTS.ASSIGNMENT.NONE') }}
                    </span>
                  </div>
                </BaseTableCell>
                <BaseTableCell align="end">
                  <div class="flex gap-2 justify-end">
                    <Button
                      xs
                      ghost
                      slate
                      icon="i-lucide-pencil"
                      @click.stop="openEditModal(agent)"
                    />
                    <Button
                      xs
                      ghost
                      class="text-n-slate-11 hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
                      icon="i-lucide-trash-2"
                      @click.stop="openDeleteConfirm(agent)"
                    />
                    <Button
                      xs
                      ghost
                      slate
                      :icon="
                        expandedAgentId === agent.id
                          ? 'i-lucide-chevron-up'
                          : 'i-lucide-chevron-down'
                      "
                      @click.stop="toggleExpand(agent)"
                    />
                  </div>
                </BaseTableCell>
              </template>
            </BaseTableRow>

            <!-- Expanded assignments -->
            <tr v-if="expandedAgentId === agent.id">
              <td colspan="6" class="px-4 py-3 bg-n-alpha-1">
                <div class="flex flex-col gap-2">
                  <div class="flex items-center justify-between mb-1">
                    <span class="text-sm font-medium text-n-slate-12">
                      {{ t('CALLS.AGENTS.ASSIGNMENTS') }}
                    </span>
                    <Button
                      xs
                      faded
                      color="blue"
                      :label="t('CALLS.AGENTS.ASSIGNMENT.ADD')"
                      icon="i-lucide-plus"
                      @click="openAssignForm"
                    />
                  </div>

                  <div
                    v-if="!agent.assignments.length && !showAssignForm"
                    class="text-sm text-n-slate-11 py-2"
                  >
                    {{ t('CALLS.AGENTS.ASSIGNMENT.NONE') }}
                  </div>

                  <div
                    v-for="asgn in agent.assignments"
                    :key="asgn.id"
                    class="flex items-center justify-between rounded-lg bg-n-solid-1 px-3 py-2"
                  >
                    <div class="flex items-center gap-3">
                      <span
                        class="inline-flex items-center rounded-full px-2 py-0.5 text-xs capitalize"
                        :class="
                          asgn.queue_name
                            ? 'bg-n-slate-3 text-n-slate-12'
                            : 'bg-n-blue-2 text-n-blue-11'
                        "
                      >
                        {{ asgn.queue_name ? t('CALLS.AGENTS.ASSIGNMENT.QUEUE') : t('CALLS.AGENTS.ASSIGNMENT.EDITION') }}
                      </span>
                      <span class="text-sm font-medium text-n-slate-12 capitalize">
                        {{ assignmentLabel(asgn) }}
                      </span>
                      <span class="text-xs text-n-slate-11">
                        {{ t('CALLS.AGENTS.ASSIGNMENT.PRIORITY') }}: {{ asgn.priority }}
                      </span>
                      <span
                        class="inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-xs"
                        :class="
                          asgn.is_active
                            ? 'bg-n-teal-2 text-n-teal-11'
                            : 'bg-n-alpha-2 text-n-slate-11'
                        "
                      >
                        {{ asgn.is_active ? 'Active' : 'Inactive' }}
                      </span>
                    </div>
                    <Button
                      xs
                      ghost
                      class="text-n-slate-11 hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
                      icon="i-lucide-trash-2"
                      @click="removeAssignment(agent.id, asgn.id)"
                    />
                  </div>

                  <!-- Add assignment form -->
                  <div
                    v-if="showAssignForm"
                    class="flex items-center gap-2 flex-wrap rounded-lg bg-n-solid-1 px-3 py-2"
                  >
                    <select
                      v-model="assignType"
                      class="rounded-lg border border-n-weak bg-n-alpha-black2 px-2 py-1.5 text-sm text-n-slate-12"
                    >
                      <option value="queue">
                        {{ t('CALLS.AGENTS.ASSIGNMENT.TYPE_QUEUE') }}
                      </option>
                      <option value="edition">
                        {{ t('CALLS.AGENTS.ASSIGNMENT.TYPE_EDITION') }}
                      </option>
                    </select>

                    <select
                      v-if="assignType === 'queue'"
                      v-model="assignQueueName"
                      class="rounded-lg border border-n-weak bg-n-alpha-black2 px-2 py-1.5 text-sm text-n-slate-12 capitalize"
                    >
                      <option v-for="q in QUEUE_OPTIONS" :key="q" :value="q">
                        {{ q }}
                      </option>
                    </select>

                    <select
                      v-else
                      v-model="assignEditionId"
                      class="rounded-lg border border-n-weak bg-n-alpha-black2 px-2 py-1.5 text-sm text-n-slate-12"
                    >
                      <option
                        v-for="ed in editions"
                        :key="ed.id"
                        :value="ed.id"
                      >
                        {{ ed.name }}
                      </option>
                    </select>

                    <div class="flex items-center gap-1">
                      <label class="text-xs text-n-slate-11">
                        {{ t('CALLS.AGENTS.ASSIGNMENT.PRIORITY') }}:
                      </label>
                      <input
                        v-model.number="assignPriority"
                        type="number"
                        min="0"
                        class="w-16 rounded-lg border border-n-weak bg-n-alpha-black2 px-2 py-1.5 text-sm text-n-slate-12"
                      />
                    </div>

                    <Button
                      xs
                      :label="t('CALLS.AGENTS.ASSIGNMENT.ADD')"
                      @click="addAssignment"
                    />
                    <Button
                      xs
                      faded
                      slate
                      :label="t('CALLS.ADD_AGENT.CANCEL')"
                      @click="cancelAssignForm"
                    />
                  </div>
                </div>
              </td>
            </tr>
          </template>
        </template>
      </BaseTable>
      <p v-else class="text-sm text-n-slate-11 py-4">
        {{ t('CALLS.AGENTS.EMPTY') }}
      </p>
    </template>

    <woot-modal v-model:show="showAddModal" :on-close="closeAddModal">
      <AddAgentModal
        ref="addModalRef"
        identity-only
        @submit="onAddAgent"
        @close="closeAddModal"
      />
    </woot-modal>

    <woot-modal v-model:show="showEditModal" :on-close="closeEditModal">
      <AddAgentModal
        ref="editModalRef"
        identity-only
        :agent="selectedAgent"
        @submit="onEditAgent"
        @close="closeEditModal"
      />
    </woot-modal>

    <woot-delete-modal
      v-model:show="showDeleteConfirm"
      :on-close="closeDeleteConfirm"
      :on-confirm="onDeleteAgent"
      :title="t('CALLS.AGENTS.DELETE_TITLE')"
      :message="t('CALLS.AGENTS.DELETE_MESSAGE')"
      :confirm-text="t('CALLS.AGENTS.DELETE_CONFIRM')"
      :reject-text="t('CALLS.AGENTS.DELETE_CANCEL')"
    />
  </SettingsLayout>
</template>
