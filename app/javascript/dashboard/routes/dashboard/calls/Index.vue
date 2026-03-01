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

const { t } = useI18n();
const router = useRouter();
const store = useStore();

const isLoading = ref(true);
const editionQueues = ref([]);
const genericQueues = ref([]);
const expandedQueue = ref(null);
const expandedAgents = ref([]);
const loadingAgents = ref(false);

// Generic queue agent modal
const showAddAgentModal = ref(false);
const selectedQueueName = ref(null);
const addAgentModalRef = ref(null);

const accountId = computed(() => store.getters.getCurrentAccountId);

const editionHeaders = computed(() => [
  t('CALLS.EDITION_QUEUES.NAME'),
  t('CALLS.EDITION_QUEUES.START_DATE'),
  t('CALLS.EDITION_QUEUES.END_DATE'),
  t('CALLS.EDITION_QUEUES.ACTIVE_NOW'),
  t('CALLS.EDITION_QUEUES.AGENTS'),
  '',
]);

const genericHeaders = computed(() => [
  t('CALLS.GENERIC_QUEUES.QUEUE_NAME'),
  t('CALLS.GENERIC_QUEUES.AGENTS'),
  '',
]);

const fetchQueues = async () => {
  isLoading.value = true;
  try {
    const { data } = await VoltAPI.getTwilioQueues();
    editionQueues.value = data.edition_queues || [];
    genericQueues.value = data.generic_queues || [];
  } catch {
    useAlert(t('CALLS.API.ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const goToEdition = edition => {
  router.push({
    name: 'calls_edition',
    params: { accountId: accountId.value, editionId: edition.edition_id },
  });
};

const toggleQueueExpand = async queue => {
  if (expandedQueue.value === queue.queue_name) {
    expandedQueue.value = null;
    expandedAgents.value = [];
    return;
  }
  expandedQueue.value = queue.queue_name;
  loadingAgents.value = true;
  try {
    const { data } = await VoltAPI.getTwilioAgents({
      queue: queue.queue_name,
    });
    expandedAgents.value = Array.isArray(data) ? data : [];
  } catch {
    expandedAgents.value = [];
  } finally {
    loadingAgents.value = false;
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

const onAddGenericAgent = async agentData => {
  try {
    await VoltAPI.addTwilioAgent({
      ...agentData,
      queue_name: selectedQueueName.value,
    });
    useAlert(t('CALLS.API.AGENT_ADDED'));
    closeAddAgentModal();
    fetchQueues();
    // Refresh expanded queue
    if (expandedQueue.value === selectedQueueName.value) {
      const { data } = await VoltAPI.getTwilioAgents({
        queue: selectedQueueName.value,
      });
      expandedAgents.value = Array.isArray(data) ? data : [];
    }
  } catch {
    useAlert(t('CALLS.API.ERROR'));
    addAgentModalRef.value?.resetSubmitting();
  }
};

const deleteGenericAgent = async agentId => {
  try {
    await VoltAPI.deleteTwilioAgent(agentId);
    useAlert(t('CALLS.API.AGENT_REMOVED'));
    fetchQueues();
    if (expandedQueue.value) {
      const { data } = await VoltAPI.getTwilioAgents({
        queue: expandedQueue.value,
      });
      expandedAgents.value = Array.isArray(data) ? data : [];
    }
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
              :key="edition.edition_id"
              :item="edition"
              class="cursor-pointer hover:bg-n-alpha-1"
              @click="goToEdition(edition)"
            >
              <template #default>
                <BaseTableCell>
                  <span class="text-body-main text-n-slate-12 font-medium">
                    {{ edition.edition_name }}
                  </span>
                </BaseTableCell>
                <BaseTableCell>
                  <span class="text-body-main text-n-slate-11">
                    {{ formatDate(edition.start_date) }}
                  </span>
                </BaseTableCell>
                <BaseTableCell>
                  <span class="text-body-main text-n-slate-11">
                    {{ formatDate(edition.end_date) }}
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
          v-if="genericQueues.length"
          :headers="genericHeaders"
          :items="genericQueues"
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
                    <span class="text-body-main text-n-slate-12 font-medium capitalize">
                      {{ queue.queue_name }}
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
                  <div v-if="loadingAgents" class="text-sm text-n-slate-11 py-2">
                    Loading...
                  </div>
                  <div v-else-if="expandedAgents.length === 0" class="text-sm text-n-slate-11 py-2">
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
                          {{ agent.agent_name || '—' }}
                        </span>
                        <span class="text-sm text-n-slate-11">
                          {{ agent.agent_phone }}
                        </span>
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
                      </div>
                      <Button
                        xs
                        ghost
                        class="text-n-slate-11 hover:enabled:text-n-ruby-11"
                        icon="i-lucide-trash-2"
                        @click="deleteGenericAgent(agent.id)"
                      />
                    </div>
                  </div>
                </td>
              </tr>
            </template>
          </template>
        </BaseTable>
        <p v-else class="text-sm text-n-slate-11 py-4">
          {{ t('CALLS.GENERIC_QUEUES.EMPTY') }}
        </p>
      </div>
    </template>

    <woot-modal v-model:show="showAddAgentModal" :on-close="closeAddAgentModal">
      <AddAgentModal
        ref="addAgentModalRef"
        @submit="onAddGenericAgent"
        @close="closeAddAgentModal"
      />
    </woot-modal>
  </SettingsLayout>
</template>
