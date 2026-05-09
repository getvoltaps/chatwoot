<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
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
import AssignAgentModal from './AssignAgentModal.vue';

const { t } = useI18n();
const route = useRoute();

const isLoading = ref(true);
const edition = ref(null);
const agents = ref([]);

const showAddModal = ref(false);
const showEditModal = ref(false);
const showDeleteConfirm = ref(false);
const selectedAgent = ref(null);
const addModalRef = ref(null);
const editModalRef = ref(null);

// Opening hours
const hoursData = ref(null);
const hoursExceptions = ref({});
const savingHours = ref(false);

const editionId = computed(() => route.params.editionId);

const assignedAgentIds = computed(() => agents.value.map(a => a.internal_user_id));

// Event day rows: 2 before + event days + 2 after
const beforeCount = ref(2);
const afterCount = ref(2);

const eventDayRows = ref([]);

const buildDateRange = (startStr, endStr) => {
  const dates = [];
  const current = new Date(startStr);
  const end = new Date(endStr);
  while (current <= end) {
    dates.push(current.toISOString().split('T')[0]);
    current.setDate(current.getDate() + 1);
  }
  return dates;
};

const formatDayLabel = dateStr => {
  const d = new Date(dateStr);
  return d.toLocaleDateString('en-GB', {
    weekday: 'short',
    day: 'numeric',
    month: 'short',
  });
};

const isEventDay = dateStr => {
  if (!edition.value?.startDate || !edition.value?.endDate) return false;
  return dateStr >= edition.value.startDate && dateStr <= edition.value.endDate;
};

const buildEventDayRows = () => {
  if (!edition.value?.startDate || !edition.value?.endDate) return;

  const start = new Date(edition.value.startDate);
  const end = new Date(edition.value.endDate);

  // Days before
  const beforeStart = new Date(start);
  beforeStart.setDate(beforeStart.getDate() - beforeCount.value);
  const beforeDates = buildDateRange(
    beforeStart.toISOString().split('T')[0],
    new Date(start.getTime() - 86400000).toISOString().split('T')[0]
  );

  // Event days
  const eventDates = buildDateRange(
    edition.value.startDate,
    edition.value.endDate
  );

  // Days after
  const afterEnd = new Date(end);
  afterEnd.setDate(afterEnd.getDate() + afterCount.value);
  const afterDates = buildDateRange(
    new Date(end.getTime() + 86400000).toISOString().split('T')[0],
    afterEnd.toISOString().split('T')[0]
  );

  const allDates = [...beforeDates, ...eventDates, ...afterDates];
  eventDayRows.value = allDates.map(date => {
    const existing = hoursExceptions.value[date];
    const hasExisting = existing !== undefined;
    return {
      date,
      closed: hasExisting ? existing.length === 0 : true,
      from: existing?.[0]?.[0] || (isEventDay(date) ? '08:00' : '09:00'),
      to: existing?.[0]?.[1] || (isEventDay(date) ? '22:00' : '17:00'),
    };
  });
};

const syncRowsToExceptions = () => {
  const updated = {};
  eventDayRows.value.forEach(row => {
    if (!row.closed && row.from && row.to) {
      updated[row.date] = [[row.from, row.to]];
    }
  });
  hoursExceptions.value = updated;
};

const editionName = computed(() => edition.value?.name || '');

const isLive = computed(() => edition.value?.is_active_now === 1);

const dateRange = computed(() => {
  if (!edition.value) return '';
  return `${formatDate(edition.value.startDate)} — ${formatDate(edition.value.endDate)}`;
});

const tableHeaders = computed(() => [
  t('CALLS.EDITION_DETAIL.NAME'),
  t('CALLS.EDITION_DETAIL.PHONE'),
  'Email',
  t('CALLS.EDITION_DETAIL.PRIORITY'),
  t('CALLS.EDITION_DETAIL.ACTIVE'),
  t('CALLS.EDITION_DETAIL.ACTIONS'),
]);

const fetchEdition = async () => {
  isLoading.value = true;
  try {
    const editionRes = await VoltAPI.getTwilioEdition(editionId.value);
    edition.value = editionRes.data;
    agents.value = editionRes.data.agents || [];
  } catch {
    useAlert(t('CALLS.API.ERROR'));
  } finally {
    isLoading.value = false;
  }

  // Load hours separately so it doesn't block the page
  try {
    const hoursRes = await VoltAPI.getEditionHours(editionId.value);
    hoursData.value = hoursRes.data;
    const hours = hoursRes.data.opening_hours || {};
    hoursExceptions.value = hours.exceptions || {};
  } catch {
    // Hours may not be configured yet — not an error
  }
  // Always build day rows from edition dates
  if (edition.value?.startDate && edition.value?.endDate) {
    buildEventDayRows();
  }
};

const saveEditionHours = async () => {
  savingHours.value = true;
  try {
    // Only save exceptions — clear all weekday schedules
    const openingHours = {
      mon: [],
      tue: [],
      wed: [],
      thu: [],
      fri: [],
      sat: [],
      sun: [],
    };
    if (Object.keys(hoursExceptions.value).length > 0) {
      openingHours.exceptions = hoursExceptions.value;
    }
    await VoltAPI.updateEditionHours(editionId.value, {
      opening_hours: openingHours,
    });
    useAlert(t('CALLS.API.HOURS_SAVED'));
    isInherited.value = false;
  } catch {
    useAlert(t('CALLS.API.ERROR'));
  } finally {
    savingHours.value = false;
  }
};

const openAddModal = () => {
  selectedAgent.value = null;
  showAddModal.value = true;
};

const closeAddModal = () => {
  showAddModal.value = false;
};

const openEditModal = agent => {
  selectedAgent.value = agent;
  showEditModal.value = true;
};

const closeEditModal = () => {
  showEditModal.value = false;
  selectedAgent.value = null;
};

const openDeleteConfirm = agent => {
  selectedAgent.value = agent;
  showDeleteConfirm.value = true;
};

const closeDeleteConfirm = () => {
  showDeleteConfirm.value = false;
  selectedAgent.value = null;
};

const onAddAgent = async ({ internal_user_id, priority }) => {
  try {
    await VoltAPI.addTwilioEditionAgent(editionId.value, {
      internal_user_id,
      priority,
    });
    useAlert(t('CALLS.API.ASSIGNMENT_ADDED'));
    closeAddModal();
    fetchEdition();
  } catch {
    useAlert(t('CALLS.API.ERROR'));
    addModalRef.value?.resetSubmitting();
  }
};

const onEditAgent = async agentData => {
  try {
    const agent = selectedAgent.value;
    if (agentData.priority !== undefined) {
      await VoltAPI.updateAgentAssignment(
        agent.internal_user_id,
        agent.assignment_id,
        { priority: agentData.priority }
      );
    }

    useAlert(t('CALLS.API.AGENT_UPDATED'));
    closeEditModal();
    fetchEdition();
  } catch {
    useAlert(t('CALLS.API.ERROR'));
    editModalRef.value?.resetSubmitting();
  }
};

const onDeleteAgent = async () => {
  const assignmentId = selectedAgent.value.assignment_id;
  try {
    await VoltAPI.removeTwilioEditionAgent(editionId.value, assignmentId);
    useAlert(t('CALLS.API.AGENT_REMOVED'));
    closeDeleteConfirm();
    fetchEdition();
  } catch {
    useAlert(t('CALLS.API.ERROR'));
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

onMounted(fetchEdition);
</script>

<template>
  <SettingsLayout
    :is-loading="isLoading"
    :loading-message="t('CALLS.LOADING')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="editionName"
        :back-button-label="t('CALLS.EDITION_DETAIL.BACK')"
      >
        <template #description>
          <div class="flex items-center gap-3">
            <span class="text-sm text-n-slate-11">{{ dateRange }}</span>
            <span
              v-if="edition"
              class="inline-flex items-center gap-1.5 rounded-full px-2 py-0.5 text-xs font-medium"
              :class="
                isLive
                  ? 'bg-n-teal-2 text-n-teal-11'
                  : 'bg-n-alpha-2 text-n-slate-11'
              "
            >
              <span
                class="size-1.5 rounded-full"
                :class="isLive ? 'bg-n-teal-9' : 'bg-n-slate-9'"
              />
              {{
                isLive
                  ? t('CALLS.EDITION_DETAIL.LIVE_BADGE')
                  : t('CALLS.EDITION_QUEUES.UPCOMING')
              }}
            </span>
          </div>
        </template>
        <template #actions>
          <Button
            :label="t('CALLS.ADD_AGENT.TITLE')"
            size="sm"
            icon="i-lucide-plus"
            @click="openAddModal"
          />
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <!-- Phone Hours Section -->
      <div v-if="edition?.startDate && edition?.endDate" class="mb-8">
        <div class="flex items-center justify-between mb-3">
          <div>
            <h3 class="text-base font-semibold text-n-slate-12">
              Phone Hours
            </h3>
            <p class="text-sm text-n-slate-11">
              Set phone hours for each day around the event. Only enabled days
              are saved.
            </p>
          </div>
          <div class="flex gap-2">
            <Button
              v-if="eventDayRows.length"
              size="sm"
              :label="t('CALLS.OPENING_HOURS.SAVE')"
              :is-loading="savingHours"
              @click="syncRowsToExceptions(); saveEditionHours()"
            />
          </div>
        </div>

        <!-- Day-by-day rows -->
        <div v-if="eventDayRows.length" class="flex flex-col gap-1">
          <div
            v-for="row in eventDayRows"
            :key="row.date"
            class="flex items-center gap-3 rounded-lg px-3 py-2"
            :class="
              isEventDay(row.date)
                ? 'bg-n-blue-2/50'
                : 'bg-n-alpha-1'
            "
          >
            <!-- Enable checkbox -->
            <input
              v-model="row.closed"
              type="checkbox"
              class="m-0"
              :true-value="false"
              :false-value="true"
            />

            <!-- Date label -->
            <div class="w-36">
              <span
                class="text-sm"
                :class="
                  row.closed
                    ? 'text-n-slate-9'
                    : isEventDay(row.date)
                      ? 'font-semibold text-n-blue-11'
                      : 'font-medium text-n-slate-12'
                "
              >
                {{ formatDayLabel(row.date) }}
              </span>
              <span
                v-if="isEventDay(row.date)"
                class="ml-1.5 text-xs text-n-blue-9"
              >
                Event
              </span>
            </div>

            <!-- Time inputs -->
            <template v-if="!row.closed">
              <input
                v-model="row.from"
                type="time"
                class="rounded-lg border border-n-weak bg-n-alpha-black2 px-2 py-1.5 text-sm text-n-slate-12"
              />
              <span class="text-n-slate-11">—</span>
              <input
                v-model="row.to"
                type="time"
                class="rounded-lg border border-n-weak bg-n-alpha-black2 px-2 py-1.5 text-sm text-n-slate-12"
              />
            </template>
            <span v-else class="text-sm text-n-slate-9 italic">
              No phone hours
            </span>
          </div>
        </div>
      </div>

      <!-- Agents Section -->
      <div>
        <h3 class="text-base font-semibold text-n-slate-12 mb-3">
          {{ t('CALLS.EDITION_DETAIL.AGENTS_TITLE') }}
        </h3>

        <BaseTable
          v-if="agents.length"
          :headers="tableHeaders"
          :items="agents"
        >
          <template #row="{ items }">
            <BaseTableRow
              v-for="agent in items"
              :key="agent.assignment_id"
              :item="agent"
            >
              <template #default>
                <BaseTableCell>
                  <span class="text-body-main text-n-slate-12">
                    {{ agent.agent_name || '—' }}
                  </span>
                </BaseTableCell>
                <BaseTableCell>
                  <span class="text-body-main text-n-slate-11">
                    {{ agent.agent_phone }}
                  </span>
                </BaseTableCell>
                <BaseTableCell>
                  <span class="text-body-main text-n-slate-11">
                    {{ agent.agent_email || '—' }}
                  </span>
                </BaseTableCell>
                <BaseTableCell>
                  <span class="text-body-main text-n-slate-11">
                    {{ agent.priority }}
                  </span>
                </BaseTableCell>
                <BaseTableCell>
                  <span
                    class="inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-xs"
                    :class="
                      agent.assignment_active
                        ? 'bg-n-teal-2 text-n-teal-11'
                        : 'bg-n-alpha-2 text-n-slate-11'
                    "
                  >
                    {{ agent.assignment_active ? 'Active' : 'Inactive' }}
                  </span>
                </BaseTableCell>
                <BaseTableCell align="end">
                  <div class="flex gap-2 justify-end">
                    <Button
                      xs
                      ghost
                      slate
                      icon="i-lucide-pencil"
                      @click="openEditModal(agent)"
                    />
                    <Button
                      xs
                      ghost
                      class="text-n-slate-11 hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
                      icon="i-lucide-trash-2"
                      @click="openDeleteConfirm(agent)"
                    />
                  </div>
                </BaseTableCell>
              </template>
            </BaseTableRow>
          </template>
        </BaseTable>
        <p v-else class="text-sm text-n-slate-11 py-4">
          {{ t('CALLS.EDITION_DETAIL.EMPTY') }}
        </p>
      </div>
    </template>

    <woot-modal v-model:show="showAddModal" :on-close="closeAddModal">
      <AssignAgentModal
        ref="addModalRef"
        :exclude-agent-ids="assignedAgentIds"
        @submit="onAddAgent"
        @close="closeAddModal"
      />
    </woot-modal>

    <woot-modal v-model:show="showEditModal" :on-close="closeEditModal">
      <AddAgentModal
        ref="editModalRef"
        :agent="selectedAgent"
        @submit="onEditAgent"
        @close="closeEditModal"
      />
    </woot-modal>

    <woot-delete-modal
      v-model:show="showDeleteConfirm"
      :on-close="closeDeleteConfirm"
      :on-confirm="onDeleteAgent"
      :title="t('CALLS.DELETE_AGENT.TITLE')"
      :message="t('CALLS.DELETE_AGENT.MESSAGE')"
      :confirm-text="t('CALLS.DELETE_AGENT.CONFIRM')"
      :reject-text="t('CALLS.DELETE_AGENT.CANCEL')"
    />
  </SettingsLayout>
</template>
