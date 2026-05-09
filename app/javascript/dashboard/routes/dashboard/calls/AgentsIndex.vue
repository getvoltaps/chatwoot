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

const { t } = useI18n();

const isLoading = ref(true);
const users = ref([]);
const editions = ref([]);
const expandedUserId = ref(null);

// Assignment form
const showAssignForm = ref(false);
const assignType = ref('queue');
const assignQueueName = ref('support');
const assignEditionId = ref('');
const assignPriority = ref(0);

const QUEUE_OPTIONS = ['support', 'hr', 'sales'];

const tableHeaders = computed(() => [
  'Name',
  'Phone',
  'Email',
  'Assignments',
  '',
]);

const fetchData = async () => {
  isLoading.value = true;
  try {
    const [usersRes, editionsRes] = await Promise.all([
      VoltAPI.getTwilioAgents(),
      VoltAPI.getTwilioEditions(),
    ]);
    users.value = Array.isArray(usersRes.data) ? usersRes.data : [];
    const HIDDEN_EDITIONS = ['Test School'];
    const THREE_DAYS_AGO = new Date();
    THREE_DAYS_AGO.setDate(THREE_DAYS_AGO.getDate() - 3);
    editions.value = (Array.isArray(editionsRes.data) ? editionsRes.data : [])
      .filter(e => !HIDDEN_EDITIONS.includes(e.name))
      .filter(e => !e.endDate || new Date(e.endDate) >= THREE_DAYS_AGO);
  } catch {
    useAlert(t('CALLS.API.ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const refreshUsers = async () => {
  try {
    const { data } = await VoltAPI.getTwilioAgents();
    users.value = Array.isArray(data) ? data : [];
  } catch {
    // silent
  }
};

const toggleExpand = user => {
  if (expandedUserId.value === user.id) {
    expandedUserId.value = null;
    showAssignForm.value = false;
  } else {
    expandedUserId.value = user.id;
    showAssignForm.value = false;
  }
};

const assignmentLabel = assignment => {
  if (assignment.queue_name) return assignment.queue_name;
  return assignment.edition_name || assignment.edition_id;
};

const openAssignForm = () => {
  assignType.value = 'queue';
  assignQueueName.value = 'support';
  assignEditionId.value = editions.value[0]?.id || '';
  assignPriority.value = 0;
  showAssignForm.value = true;
};

const addAssignment = async () => {
  const userId = expandedUserId.value;
  const data = { priority: assignPriority.value, is_active: 1 };
  if (assignType.value === 'queue') {
    data.queue_name = assignQueueName.value;
  } else {
    data.edition_id = assignEditionId.value;
  }
  try {
    await VoltAPI.addAgentAssignment(userId, data);
    useAlert(t('CALLS.API.ASSIGNMENT_ADDED'));
    showAssignForm.value = false;
    await refreshUsers();
  } catch {
    useAlert(t('CALLS.API.ERROR'));
  }
};

const removeAssignment = async (userId, assignmentId) => {
  try {
    await VoltAPI.deleteAgentAssignment(userId, assignmentId);
    useAlert(t('CALLS.API.ASSIGNMENT_REMOVED'));
    await refreshUsers();
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
        title="Phone Agents"
        description="Staff members with phone numbers who can receive calls. Assign them to queues and editions."
      />
    </template>

    <template #body>
      <BaseTable
        v-if="users.length"
        :headers="tableHeaders"
        :items="users"
      >
        <template #row="{ items }">
          <template v-for="user in items" :key="user.id">
            <BaseTableRow
              :item="user"
              class="cursor-pointer hover:bg-n-alpha-1"
              @click="toggleExpand(user)"
            >
              <template #default>
                <BaseTableCell>
                  <span class="text-body-main text-n-slate-12 font-medium">
                    {{ user.name || '—' }}
                  </span>
                </BaseTableCell>
                <BaseTableCell>
                  <span class="text-body-main text-n-slate-11">
                    {{ user.phonenumber }}
                  </span>
                </BaseTableCell>
                <BaseTableCell>
                  <span class="text-body-main text-n-slate-11">
                    {{ user.email || '—' }}
                  </span>
                </BaseTableCell>
                <BaseTableCell>
                  <div class="flex flex-wrap gap-1">
                    <span
                      v-for="asgn in (user.assignments || [])"
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
                      v-if="!(user.assignments || []).length"
                      class="text-xs text-n-slate-9"
                    >
                      No assignments
                    </span>
                  </div>
                </BaseTableCell>
                <BaseTableCell align="end">
                  <Button
                    xs
                    ghost
                    slate
                    :icon="
                      expandedUserId === user.id
                        ? 'i-lucide-chevron-up'
                        : 'i-lucide-chevron-down'
                    "
                    @click.stop="toggleExpand(user)"
                  />
                </BaseTableCell>
              </template>
            </BaseTableRow>

            <!-- Expanded assignments -->
            <tr v-if="expandedUserId === user.id">
              <td colspan="5" class="px-4 py-3 bg-n-alpha-1">
                <div class="flex flex-col gap-2">
                  <div class="flex items-center justify-between mb-1">
                    <span class="text-sm font-medium text-n-slate-12">
                      Assignments
                    </span>
                    <Button
                      xs
                      faded
                      color="blue"
                      label="Add Assignment"
                      icon="i-lucide-plus"
                      @click="openAssignForm"
                    />
                  </div>

                  <div
                    v-if="!(user.assignments || []).length && !showAssignForm"
                    class="text-sm text-n-slate-11 py-2"
                  >
                    No assignments yet
                  </div>

                  <div
                    v-for="asgn in (user.assignments || [])"
                    :key="asgn.id"
                    class="flex items-center justify-between rounded-lg bg-n-solid-1 px-3 py-2"
                  >
                    <div class="flex items-center gap-3">
                      <span class="text-sm font-medium text-n-slate-12 capitalize">
                        {{ assignmentLabel(asgn) }}
                      </span>
                      <span class="text-xs text-n-slate-9">
                        Priority: {{ asgn.priority }}
                      </span>
                    </div>
                    <Button
                      xs
                      ghost
                      class="text-n-slate-11 hover:enabled:text-n-ruby-11"
                      icon="i-lucide-x"
                      @click="removeAssignment(user.id, asgn.id)"
                    />
                  </div>

                  <!-- Add assignment form -->
                  <div
                    v-if="showAssignForm"
                    class="flex items-end gap-2 rounded-lg bg-n-solid-1 px-3 py-2"
                  >
                    <div>
                      <label class="text-xs text-n-slate-11">Type</label>
                      <select
                        v-model="assignType"
                        class="block mt-0.5 rounded-lg border border-n-weak bg-n-solid-2 px-2 py-1.5 text-sm text-n-slate-12"
                      >
                        <option value="queue">Queue</option>
                        <option value="edition">Edition</option>
                      </select>
                    </div>
                    <div v-if="assignType === 'queue'">
                      <label class="text-xs text-n-slate-11">Queue</label>
                      <select
                        v-model="assignQueueName"
                        class="block mt-0.5 rounded-lg border border-n-weak bg-n-solid-2 px-2 py-1.5 text-sm text-n-slate-12"
                      >
                        <option
                          v-for="q in QUEUE_OPTIONS"
                          :key="q"
                          :value="q"
                        >
                          {{ q }}
                        </option>
                      </select>
                    </div>
                    <div v-else>
                      <label class="text-xs text-n-slate-11">Edition</label>
                      <select
                        v-model="assignEditionId"
                        class="block mt-0.5 rounded-lg border border-n-weak bg-n-solid-2 px-2 py-1.5 text-sm text-n-slate-12"
                      >
                        <option
                          v-for="ed in editions"
                          :key="ed.id"
                          :value="ed.id"
                        >
                          {{ ed.name }}
                        </option>
                      </select>
                    </div>
                    <div>
                      <label class="text-xs text-n-slate-11">Priority</label>
                      <input
                        v-model.number="assignPriority"
                        type="number"
                        min="0"
                        class="block mt-0.5 w-16 rounded-lg border border-n-weak bg-n-solid-2 px-2 py-1.5 text-sm text-n-slate-12"
                      />
                    </div>
                    <Button
                      xs
                      faded
                      color="blue"
                      label="Add"
                      @click="addAssignment"
                    />
                    <Button
                      xs
                      ghost
                      slate
                      label="Cancel"
                      @click="showAssignForm = false"
                    />
                  </div>
                </div>
              </td>
            </tr>
          </template>
        </template>
      </BaseTable>
      <p v-else class="text-sm text-n-slate-11 py-4">
        No staff members with phone numbers found.
      </p>
    </template>
  </SettingsLayout>
</template>
