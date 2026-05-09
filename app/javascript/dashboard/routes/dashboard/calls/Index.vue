<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useRouter } from 'vue-router';
import { useStore } from 'dashboard/composables/store';
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
import AssignAgentModal from './AssignAgentModal.vue';
import OpeningHoursEditor from './OpeningHoursEditor.vue';
import ExceptionsEditor from './ExceptionsEditor.vue';

const { t } = useI18n();
const router = useRouter();
const store = useStore();

const isLoading = ref(true);
const editionQueues = ref([]);
const genericQueues = ref([]);
const allAgents = ref([]);
const expandedQueue = ref(null);

// Generic queue agent modals
const showAddAgentModal = ref(false);
const showEditAgentModal = ref(false);
const selectedQueueName = ref(null);
const selectedAgent = ref(null);
const addAgentModalRef = ref(null);
const editAgentModalRef = ref(null);

// Opening hours modal
const showHoursModal = ref(false);
const hoursQueueName = ref(null);
const hoursSchedule = ref({});
const hoursExceptions = ref({});
const loadingHours = ref(false);
const savingHours = ref(false);

const accountId = computed(() => store.getters.getCurrentAccountId);

const editionHeaders = computed(() => [
  t('CALLS.EDITION_QUEUES.NAME'),
  t('CALLS.EDITION_QUEUES.START_DATE'),
  t('CALLS.EDITION_QUEUES.END_DATE'),
  t('CALLS.EDITION_QUEUES.ACTIVE_NOW'),
  t('CALLS.EDITION_QUEUES.AGENTS'),
  '',
]);

const GENERIC_QUEUE_NAMES = ['support', 'hr', 'sales'];
const QUEUE_DISPLAY_NAMES = { support: 'Support', hr: 'HR', sales: 'Sales' };

const genericHeaders = computed(() => [
  t('CALLS.GENERIC_QUEUES.QUEUE_NAME'),
  t('CALLS.GENERIC_QUEUES.AGENTS'),
  '',
]);

const mergedGenericQueues = computed(() =>
  GENERIC_QUEUE_NAMES.map(name => {
    const fromApi = genericQueues.value.find(q => q.queue_name === name);
    return {
      queue_name: name,
      display_name: QUEUE_DISPLAY_NAMES[name] || name,
      total_agents: fromApi?.total_agents ?? 0,
      active_agents: fromApi?.active_agents ?? 0,
    };
  })
);

const expandedAgents = computed(() => {
  if (!expandedQueue.value) return [];
  return allAgents.value.filter(agent =>
    (agent.assignments || []).some(a => a.queue_name === expandedQueue.value)
  );
});

const excludedAgentIds = computed(() => expandedAgents.value.map(a => a.id));

const getQueueAssignment = (agent, queueName) => {
  return (agent.assignments || []).find(a => a.queue_name === queueName);
};

const fetchQueues = async () => {
  isLoading.value = true;
  try {
    const [editionsRes, queuesRes, agentsRes] = await Promise.all([
      VoltAPI.getTwilioEditions(),
      VoltAPI.getTwilioQueues(),
      VoltAPI.getTwilioAgents(),
    ]);
    const HIDDEN_EDITIONS = ['Test School'];
    const THREE_DAYS_AGO = new Date();
    THREE_DAYS_AGO.setDate(THREE_DAYS_AGO.getDate() - 3);

    editionQueues.value = (Array.isArray(editionsRes.data) ? editionsRes.data : [])
      .filter(e => !HIDDEN_EDITIONS.includes(e.name))
      .filter(e => !e.endDate || new Date(e.endDate) >= THREE_DAYS_AGO);
    genericQueues.value = queuesRes.data?.generic_queues || [];
    allAgents.value = Array.isArray(agentsRes.data) ? agentsRes.data : [];
  } catch {
    useAlert(t('CALLS.API.ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const refreshAgents = async () => {
  try {
    const [queuesRes, agentsRes] = await Promise.all([
      VoltAPI.getTwilioQueues(),
      VoltAPI.getTwilioAgents(),
    ]);
    genericQueues.value = queuesRes.data?.generic_queues || [];
    allAgents.value = Array.isArray(agentsRes.data) ? agentsRes.data : [];
  } catch {
    // silent
  }
};

const goToEdition = edition => {
  router.push({
    name: 'calls_edition',
    params: { accountId: accountId.value, editionId: edition.id },
  });
};

const toggleQueueExpand = queue => {
  if (expandedQueue.value === queue.queue_name) {
    expandedQueue.value = null;
  } else {
    expandedQueue.value = queue.queue_name;
  }
};

const openAddAgentModal = queueName => {
  selectedQueueName.value = queueName;
  showAddAgentModal.value = true;
};

const closeAddAgentModal = () => {
  showAddAgentModal.value = false;
  selectedQueueName.value = null;
};

const onAddGenericAgent = async ({ internal_user_id, priority }) => {
  const queueName = selectedQueueName.value;
  try {
    await VoltAPI.addAgentAssignment(internal_user_id, {
      queue_name: queueName,
      priority,
    });
    useAlert(t('CALLS.API.ASSIGNMENT_ADDED'));
    closeAddAgentModal();
    await refreshAgents();
    expandedQueue.value = queueName;
  } catch {
    useAlert(t('CALLS.API.ERROR'));
    addAgentModalRef.value?.resetSubmitting();
  }
};

const openEditAgentModal = agent => {
  selectedAgent.value = agent;
  showEditAgentModal.value = true;
};

const closeEditAgentModal = () => {
  showEditAgentModal.value = false;
  selectedAgent.value = null;
};

const onEditGenericAgent = async agentData => {
  try {
    const agent = selectedAgent.value;
    // Update assignment priority
    const assignment = getQueueAssignment(agent, expandedQueue.value);
    if (assignment && agentData.priority !== undefined) {
      await VoltAPI.updateAgentAssignment(agent.id, assignment.id, {
        priority: agentData.priority,
      });
    }
    useAlert(t('CALLS.API.AGENT_UPDATED'));
    closeEditAgentModal();
    await refreshAgents();
  } catch {
    useAlert(t('CALLS.API.ERROR'));
    editAgentModalRef.value?.resetSubmitting();
  }
};

const deleteGenericAgent = async agent => {
  const assignment = getQueueAssignment(agent, expandedQueue.value);
  if (!assignment) return;
  try {
    await VoltAPI.deleteAgentAssignment(agent.id, assignment.id);
    useAlert(t('CALLS.API.ASSIGNMENT_REMOVED'));
    await refreshAgents();
  } catch {
    useAlert(t('CALLS.API.ERROR'));
  }
};

const openHoursModal = async queueName => {
  hoursQueueName.value = queueName;
  showHoursModal.value = true;
  loadingHours.value = true;
  try {
    const { data } = await VoltAPI.getQueueHours(queueName);
    const hours = data.opening_hours || {};
    const { exceptions, ...weekdays } = hours;
    hoursSchedule.value = weekdays;
    hoursExceptions.value = exceptions || {};
  } catch {
    hoursSchedule.value = {};
    hoursExceptions.value = {};
  } finally {
    loadingHours.value = false;
  }
};

const closeHoursModal = () => {
  showHoursModal.value = false;
  hoursQueueName.value = null;
  hoursSchedule.value = {};
  hoursExceptions.value = {};
};

const onUpdateSchedule = schedule => {
  hoursSchedule.value = schedule;
};

const onUpdateExceptions = exceptions => {
  hoursExceptions.value = exceptions;
};

const saveQueueHours = async () => {
  savingHours.value = true;
  try {
    const openingHours = { ...hoursSchedule.value };
    if (Object.keys(hoursExceptions.value).length > 0) {
      openingHours.exceptions = hoursExceptions.value;
    }
    await VoltAPI.updateQueueHours(hoursQueueName.value, {
      opening_hours: openingHours,
    });
    useAlert(t('CALLS.API.HOURS_SAVED'));
    closeHoursModal();
  } catch {
    useAlert(t('CALLS.API.ERROR'));
  } finally {
    savingHours.value = false;
  }
};

const formatDate = dateStr => {
  if (!dateStr) return '—';
  return new Date(dateStr).toLocaleDateString('en-GB', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  });
};

onMounted(fetchQueues);
</script>

<template>
  <SettingsLayout
    :is-loading="isLoading"
    :loading-message="t('CALLS.LOADING')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="t('CALLS.HEADER')"
        :description="t('CALLS.DESCRIPTION')"
      />
    </template>

    <template #body>
      <!-- Edition Queues -->
      <div class="mb-8">
        <div class="flex items-center justify-between mb-3">
          <div>
            <h2 class="text-lg font-semibold text-n-slate-12">
              {{ t('CALLS.EDITION_QUEUES.TITLE') }}
            </h2>
            <p class="text-sm text-n-slate-11">
              {{ t('CALLS.EDITION_QUEUES.DESCRIPTION') }}
            </p>
          </div>
        </div>

        <BaseTable
          v-if="editionQueues.length"
          :headers="editionHeaders"
          :items="editionQueues"
        >
          <template #row="{ items }">
            <BaseTableRow
              v-for="edition in items"
              :key="edition.id"
              :item="edition"
              class="cursor-pointer hover:bg-n-alpha-1"
              @click="goToEdition(edition)"
            >
              <template #default>
                <BaseTableCell>
                  <span class="text-body-main text-n-slate-12 font-medium">
                    {{ edition.name }}
                  </span>
                </BaseTableCell>
                <BaseTableCell>
                  <span class="text-body-main text-n-slate-11">
                    {{ formatDate(edition.startDate) }}
                  </span>
                </BaseTableCell>
                <BaseTableCell>
                  <span class="text-body-main text-n-slate-11">
                    {{ formatDate(edition.endDate) }}
                  </span>
                </BaseTableCell>
                <BaseTableCell>
                  <span
                    class="inline-flex items-center gap-1.5 rounded-full px-2 py-0.5 text-xs font-medium"
                    :class="
                      edition.is_active_now
                        ? 'bg-n-teal-2 text-n-teal-11'
                        : 'bg-n-alpha-2 text-n-slate-11'
                    "
                  >
                    <span
                      class="size-1.5 rounded-full"
                      :class="
                        edition.is_active_now ? 'bg-n-teal-9' : 'bg-n-slate-9'
                      "
                    />
                    {{
                      edition.is_active_now
                        ? t('CALLS.EDITION_QUEUES.LIVE')
                        : t('CALLS.EDITION_QUEUES.UPCOMING')
                    }}
                  </span>
                </BaseTableCell>
                <BaseTableCell>
                  <span class="text-body-main text-n-slate-11">
                    {{ edition.active_agents }}/{{ edition.total_agents }}
                  </span>
                </BaseTableCell>
                <BaseTableCell align="end">
                  <Button
                    xs
                    ghost
                    slate
                    icon="i-lucide-chevron-right"
                    @click.stop="goToEdition(edition)"
                  />
                </BaseTableCell>
              </template>
            </BaseTableRow>
          </template>
        </BaseTable>
        <p v-else class="text-sm text-n-slate-11 py-4">
          {{ t('CALLS.EDITION_QUEUES.EMPTY') }}
        </p>
      </div>

      <!-- Generic Queues -->
      <div>
        <div class="flex items-center justify-between mb-3">
          <div>
            <h2 class="text-lg font-semibold text-n-slate-12">
              {{ t('CALLS.GENERIC_QUEUES.TITLE') }}
            </h2>
            <p class="text-sm text-n-slate-11">
              {{ t('CALLS.GENERIC_QUEUES.DESCRIPTION') }}
            </p>
          </div>
        </div>

        <BaseTable
          :headers="genericHeaders"
          :items="mergedGenericQueues"
        >
          <template #row="{ items }">
            <template v-for="queue in items" :key="queue.queue_name">
              <BaseTableRow
                :item="queue"
                class="cursor-pointer hover:bg-n-alpha-1"
                @click="toggleQueueExpand(queue)"
              >
                <template #default>
                  <BaseTableCell>
                    <span class="text-body-main text-n-slate-12 font-medium">
                      {{ queue.display_name }}
                    </span>
                  </BaseTableCell>
                  <BaseTableCell>
                    <span class="text-body-main text-n-slate-11">
                      {{ queue.active_agents }}/{{ queue.total_agents }}
                    </span>
                  </BaseTableCell>
                  <BaseTableCell align="end">
                    <div class="flex items-center gap-2 justify-end">
                      <Button
                        xs
                        faded
                        slate
                        icon="i-lucide-clock"
                        @click.stop="openHoursModal(queue.queue_name)"
                      />
                      <Button
                        xs
                        faded
                        color="blue"
                        :label="t('CALLS.ADD_AGENT.TITLE')"
                        icon="i-lucide-plus"
                        @click.stop="openAddAgentModal(queue.queue_name)"
                      />
                      <Button
                        xs
                        ghost
                        slate
                        :icon="
                          expandedQueue === queue.queue_name
                            ? 'i-lucide-chevron-up'
                            : 'i-lucide-chevron-down'
                        "
                        @click.stop="toggleQueueExpand(queue)"
                      />
                    </div>
                  </BaseTableCell>
                </template>
              </BaseTableRow>

              <!-- Expanded agents -->
              <tr
                v-if="expandedQueue === queue.queue_name"
              >
                <td colspan="3" class="px-4 py-3 bg-n-alpha-1">
                  <div v-if="expandedAgents.length === 0" class="text-sm text-n-slate-11 py-2">
                    No agents in this queue.
                  </div>
                  <div v-else class="flex flex-col gap-2">
                    <div
                      v-for="agent in expandedAgents"
                      :key="agent.id"
                      class="flex items-center justify-between rounded-lg bg-n-solid-1 px-3 py-2"
                    >
                      <div class="flex items-center gap-3">
                        <span class="text-sm font-medium text-n-slate-12">
                          {{ agent.name || '—' }}
                        </span>
                        <span class="text-sm text-n-slate-11">
                          {{ agent.phonenumber }}
                        </span>
                      </div>
                      <div class="flex items-center gap-1">
                        <Button
                          xs
                          ghost
                          slate
                          icon="i-lucide-pencil"
                          @click="openEditAgentModal(agent)"
                        />
                        <Button
                          xs
                          ghost
                          class="text-n-slate-11 hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
                          icon="i-lucide-trash-2"
                          @click="deleteGenericAgent(agent)"
                        />
                      </div>
                    </div>
                  </div>
                </td>
              </tr>
            </template>
          </template>
        </BaseTable>
      </div>
    </template>

    <woot-modal v-model:show="showAddAgentModal" :on-close="closeAddAgentModal">
      <AssignAgentModal
        ref="addAgentModalRef"
        :exclude-agent-ids="excludedAgentIds"
        @submit="onAddGenericAgent"
        @close="closeAddAgentModal"
      />
    </woot-modal>

    <woot-modal v-model:show="showEditAgentModal" :on-close="closeEditAgentModal">
      <AddAgentModal
        ref="editAgentModalRef"
        :agent="selectedAgent"
        @submit="onEditGenericAgent"
        @close="closeEditAgentModal"
      />
    </woot-modal>

    <woot-modal v-model:show="showHoursModal" :on-close="closeHoursModal">
      <div class="flex flex-col p-6 gap-4">
        <div>
          <h2 class="text-lg font-semibold text-n-slate-12">
            {{ QUEUE_DISPLAY_NAMES[hoursQueueName] || hoursQueueName }} — {{ t('CALLS.OPENING_HOURS.TITLE') }}
          </h2>
          <p class="text-sm text-n-slate-11 mt-1">
            {{ t('CALLS.OPENING_HOURS.DESCRIPTION') }}
          </p>
          <p
            v-if="hoursQueueName === 'support'"
            class="text-xs text-n-amber-11 bg-n-amber-2 rounded-lg px-3 py-2 mt-2"
          >
            {{ t('CALLS.OPENING_HOURS.SUPPORT_NOTE') }}
          </p>
        </div>

        <div v-if="loadingHours" class="text-sm text-n-slate-11 py-4">
          Loading...
        </div>
        <template v-else>
          <OpeningHoursEditor
            :schedule="hoursSchedule"
            @update="onUpdateSchedule"
          />
          <ExceptionsEditor
            :exceptions="hoursExceptions"
            @update="onUpdateExceptions"
          />
        </template>

        <div class="flex justify-end gap-2 pt-2">
          <Button
            faded
            slate
            :label="t('CALLS.ADD_AGENT.CANCEL')"
            @click="closeHoursModal"
          />
          <Button
            :label="t('CALLS.OPENING_HOURS.SAVE')"
            :is-loading="savingHours"
            @click="saveQueueHours"
          />
        </div>
      </div>
    </woot-modal>
  </SettingsLayout>
</template>
