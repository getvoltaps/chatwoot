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

const editionId = computed(() => route.params.editionId);

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

const fetchEdition = async () => {
  isLoading.value = true;
  try {
    const { data } = await VoltAPI.getTwilioEdition(editionId.value);
    edition.value = data;
    agents.value = data.agents || [];
  } catch {
    useAlert(t('CALLS.API.ERROR'));
  } finally {
    isLoading.value = false;
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

const onAddAgent = async agentData => {
  try {
    await VoltAPI.addTwilioEditionAgent(editionId.value, agentData);
    useAlert(t('CALLS.API.AGENT_ADDED'));
    closeAddModal();
    fetchEdition();
  } catch {
    useAlert(t('CALLS.API.ERROR'));
    addModalRef.value?.resetSubmitting();
  }
};

const onEditAgent = async agentData => {
  try {
    await VoltAPI.updateTwilioAgent(selectedAgent.value.id, agentData);
    useAlert(t('CALLS.API.AGENT_UPDATED'));
    closeEditModal();
    fetchEdition();
  } catch {
    useAlert(t('CALLS.API.ERROR'));
    editModalRef.value?.resetSubmitting();
  }
};

const onDeleteAgent = async () => {
  try {
    await VoltAPI.removeTwilioEditionAgent(
      editionId.value,
      selectedAgent.value.id
    );
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
    :no-records-found="!isLoading && agents.length === 0"
    :no-records-message="t('CALLS.EDITION_DETAIL.EMPTY')"
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
      <BaseTable :headers="tableHeaders" :items="agents">
        <template #row="{ items }">
          <BaseTableRow
            v-for="agent in items"
            :key="agent.id"
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
                    agent.is_active
                      ? 'bg-n-teal-2 text-n-teal-11'
                      : 'bg-n-alpha-2 text-n-slate-11'
                  "
                >
                  {{ agent.is_active ? 'Active' : 'Inactive' }}
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
    </template>

    <woot-modal v-model:show="showAddModal" :on-close="closeAddModal">
      <AddAgentModal
        ref="addModalRef"
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
