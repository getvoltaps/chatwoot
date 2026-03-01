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
import OpeningHoursEditor from './OpeningHoursEditor.vue';
import ExceptionsEditor from './ExceptionsEditor.vue';

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
const hoursSchedule = ref({});
const hoursExceptions = ref({});
const isInherited = ref(true);
const useCustomHours = ref(false);
const savingHours = ref(false);

const editionId = computed(() => route.params.editionId);

const assignedAgentIds = computed(() => agents.value.map(a => a.agent_id));

const editionName = computed(() => edition.value?.name || '');

const isLive = computed(() => edition.value?.is_active_now === 1);

const dateRange = computed(() => {
  if (!edition.value) return '';
  return `${formatDate(edition.value.startDate)} — ${formatDate(edition.value.endDate)}`;
});

const tableHeaders = computed(() => [
  t('CALLS.EDITION_DETAIL.NAME'),
  t('CALLS.EDITION_DETAIL.PHONE'),
  t('CALLS.EDITION_DETAIL.PRIORITY'),
  t('CALLS.EDITION_DETAIL.SHOW_CALLER_ID'),
  t('CALLS.EDITION_DETAIL.ACTIVE'),
  t('CALLS.EDITION_DETAIL.ACTIONS'),
]);

const isAgentActive = agent => {
  return agent.agent_active && agent.assignment_active;
};

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
    const { exceptions, ...weekdays } = hours;
    hoursSchedule.value = weekdays;
    hoursExceptions.value = exceptions || {};
    isInherited.value = hoursRes.data.inherited_from === 'support';
    useCustomHours.value = !isInherited.value && hoursRes.data.opening_hours != null;
  } catch {
    // Hours may not be configured yet — not an error
  }
};

const enableCustomHours = () => {
  useCustomHours.value = true;
};

const resetToInherit = async () => {
  try {
    await VoltAPI.deleteEditionHours(editionId.value);
    useAlert(t('CALLS.API.HOURS_RESET'));
    // Reload hours
    const { data } = await VoltAPI.getEditionHours(editionId.value);
    hoursData.value = data;
    const hours = data.opening_hours || {};
    const { exceptions, ...weekdays } = hours;
    hoursSchedule.value = weekdays;
    hoursExceptions.value = exceptions || {};
    isInherited.value = data.inherited_from === 'support';
    useCustomHours.value = false;
  } catch {
    useAlert(t('CALLS.API.ERROR'));
  }
};

const saveEditionHours = async () => {
  savingHours.value = true;
  try {
    const openingHours = { ...hoursSchedule.value };
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

const onUpdateSchedule = schedule => {
  hoursSchedule.value = schedule;
};

const onUpdateExceptions = exceptions => {
  hoursExceptions.value = exceptions;
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

const onAddAgent = async ({ agent_id, priority }) => {
  try {
    await VoltAPI.addAgentAssignment(agent_id, {
      edition_id: editionId.value,
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
    // Update agent identity (name, phone, show_caller_id, is_active)
    const identityData = {
      agent_phone: agentData.agent_phone,
      agent_name: agentData.agent_name,
      show_caller_id: agentData.show_caller_id,
      is_active: agentData.is_active,
    };
    await VoltAPI.updateTwilioAgent(agent.agent_id, identityData);

    // Update assignment fields (priority)
    if (agentData.priority !== undefined) {
      await VoltAPI.updateAgentAssignment(
        agent.agent_id,
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
      <!-- Opening Hours Section -->
      <div class="mb-8">
        <div class="flex items-center justify-between mb-3">
          <div>
            <h3 class="text-base font-semibold text-n-slate-12">
              {{ t('CALLS.OPENING_HOURS.TITLE') }}
            </h3>
            <p class="text-sm text-n-slate-11">
              {{ t('CALLS.OPENING_HOURS.DESCRIPTION') }}
            </p>
          </div>
          <div class="flex gap-2">
            <Button
              v-if="isInherited && !useCustomHours"
              size="sm"
              faded
              color="blue"
              :label="t('CALLS.OPENING_HOURS.USE_CUSTOM')"
              icon="i-lucide-pencil"
              @click="enableCustomHours"
            />
            <template v-if="useCustomHours || (!isInherited && hoursData?.opening_hours)">
              <Button
                size="sm"
                faded
                slate
                :label="t('CALLS.OPENING_HOURS.RESET_INHERIT')"
                icon="i-lucide-undo-2"
                @click="resetToInherit"
              />
              <Button
                size="sm"
                :label="t('CALLS.OPENING_HOURS.SAVE')"
                :is-loading="savingHours"
                @click="saveEditionHours"
              />
            </template>
          </div>
        </div>

        <div
          v-if="isInherited && !useCustomHours"
          class="text-xs text-n-blue-11 bg-n-blue-2 rounded-lg px-3 py-2 mb-3"
        >
          {{ t('CALLS.OPENING_HOURS.INHERITING') }}
        </div>

        <OpeningHoursEditor
          :schedule="hoursSchedule"
          :readonly="isInherited && !useCustomHours"
          @update="onUpdateSchedule"
        />
        <ExceptionsEditor
          :exceptions="hoursExceptions"
          :readonly="isInherited && !useCustomHours"
          @update="onUpdateExceptions"
        />
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
                    {{ agent.priority }}
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
                      isAgentActive(agent)
                        ? 'bg-n-teal-2 text-n-teal-11'
                        : 'bg-n-alpha-2 text-n-slate-11'
                    "
                  >
                    {{ isAgentActive(agent) ? 'Active' : 'Inactive' }}
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
