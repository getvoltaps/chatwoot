<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import ReportHeader from './components/ReportHeader.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import VoltAPI from 'dashboard/api/integrations/volt';

const { t } = useI18n();

const isLoading = ref(false);
const isSummaryLoading = ref(false);
const reportData = ref(null);
const since = ref('');
const untilDate = ref('');

const topEditions = computed(() => {
  if (!reportData.value) return [];
  return reportData.value.editions.slice(0, 5);
});

const otherEditions = computed(() => {
  if (!reportData.value) return [];
  return reportData.value.editions.slice(5);
});

const fetchReport = async () => {
  isLoading.value = true;
  isSummaryLoading.value = true;
  try {
    const { data } = await VoltAPI.getEditionReport({
      since: since.value || undefined,
      until: untilDate.value || undefined,
    });
    reportData.value = data;
  } catch {
    reportData.value = null;
  } finally {
    isLoading.value = false;
    isSummaryLoading.value = false;
  }
};

fetchReport();
</script>

<template>
  <ReportHeader
    :header-title="t('VOLT_EDITION_REPORTS.TITLE')"
    :header-description="t('VOLT_EDITION_REPORTS.DESCRIPTION')"
  />
  <div class="flex flex-col gap-6">
    <!-- Date Filters -->
    <div class="flex items-end gap-3">
      <div class="flex flex-col gap-1">
        <label class="text-xs font-medium text-n-slate-11">
          {{ t('VOLT_EDITION_REPORTS.FROM') }}
        </label>
        <input
          v-model="since"
          type="date"
          class="rounded-lg border border-n-weak bg-n-alpha-1 px-3 py-1.5 text-sm text-n-slate-12"
        />
      </div>
      <div class="flex flex-col gap-1">
        <label class="text-xs font-medium text-n-slate-11">
          {{ t('VOLT_EDITION_REPORTS.TO') }}
        </label>
        <input
          v-model="untilDate"
          type="date"
          class="rounded-lg border border-n-weak bg-n-alpha-1 px-3 py-1.5 text-sm text-n-slate-12"
        />
      </div>
      <NextButton
        :label="t('VOLT_EDITION_REPORTS.APPLY')"
        variant="faded"
        color="blue"
        size="sm"
        :is-loading="isLoading"
        @click="fetchReport"
      />
    </div>

    <!-- Loading State -->
    <div v-if="isLoading" class="flex items-center gap-2 py-8">
      <Spinner :size="16" />
      <span class="text-sm text-n-slate-11">
        {{ t('VOLT_EDITION_REPORTS.LOADING') }}
      </span>
    </div>

    <!-- Report Content -->
    <template v-else-if="reportData">
      <!-- Summary Cards -->
      <div class="grid grid-cols-3 gap-4">
        <div class="rounded-lg border border-n-weak p-4">
          <div class="text-xs font-medium text-n-slate-11 mb-1">
            {{ t('VOLT_EDITION_REPORTS.TOTAL_TICKETS') }}
          </div>
          <span class="text-2xl font-semibold text-n-slate-12">
            {{ reportData.total_tickets }}
          </span>
        </div>
        <div class="rounded-lg border border-n-weak p-4">
          <div class="text-xs font-medium text-n-slate-11 mb-1">
            {{ t('VOLT_EDITION_REPORTS.WITH_EDITION') }}
          </div>
          <span class="text-2xl font-semibold text-n-slate-12">
            {{ reportData.total_with_edition }}
          </span>
        </div>
        <div class="rounded-lg border border-n-weak p-4">
          <div class="text-xs font-medium text-n-slate-11 mb-1">
            {{ t('VOLT_EDITION_REPORTS.EDITIONS_COUNT') }}
          </div>
          <span class="text-2xl font-semibold text-n-slate-12">
            {{ reportData.editions.length }}
          </span>
        </div>
      </div>

      <!-- Top 5 Editions -->
      <div v-if="topEditions.length > 0">
        <h3 class="text-heading-2 text-n-slate-12 mb-4">
          {{ t('VOLT_EDITION_REPORTS.TOP_EDITIONS') }}
        </h3>
        <div class="flex flex-col gap-3">
          <div
            v-for="(edition, index) in topEditions"
            :key="edition.name"
            class="rounded-lg border border-n-weak p-4"
          >
            <div class="flex items-center justify-between mb-2">
              <div class="flex items-center gap-2">
                <span
                  class="flex items-center justify-center size-6 rounded-full bg-n-blue-3 text-xs font-semibold text-n-blue-11"
                >
                  {{ index + 1 }}
                </span>
                <span class="text-sm font-medium text-n-slate-12">
                  {{ edition.name }}
                </span>
              </div>
              <span class="text-sm font-semibold text-n-slate-12">
                {{ edition.count }}
                {{ t('VOLT_EDITION_REPORTS.TICKETS') }}
              </span>
            </div>
            <!-- Progress bar -->
            <div class="h-2 rounded-full bg-n-weak overflow-hidden mb-2">
              <div
                class="h-full rounded-full bg-n-blue-9 transition-all"
                :style="{
                  width: `${(edition.count / topEditions[0].count) * 100}%`,
                }"
              />
            </div>
            <!-- AI Summary -->
            <div
              v-if="reportData.summaries[edition.name]"
              class="mt-2 text-sm text-n-slate-11 bg-n-alpha-1 rounded-lg p-3"
            >
              <div class="flex items-center gap-1.5 mb-1">
                <span
                  class="i-ph-sparkle-fill text-n-blue-11 text-xs flex-shrink-0"
                />
                <span class="text-xs font-medium text-n-blue-11">
                  {{ t('VOLT_EDITION_REPORTS.AI_SUMMARY') }}
                </span>
              </div>
              {{ reportData.summaries[edition.name] }}
            </div>
            <div
              v-else-if="isSummaryLoading"
              class="mt-2 flex items-center gap-2"
            >
              <Spinner :size="12" />
              <span class="text-xs text-n-slate-11">
                {{ t('VOLT_EDITION_REPORTS.GENERATING_SUMMARY') }}
              </span>
            </div>
          </div>
        </div>
      </div>

      <!-- Other Editions Table -->
      <div v-if="otherEditions.length > 0">
        <h3 class="text-heading-2 text-n-slate-12 mb-4">
          {{ t('VOLT_EDITION_REPORTS.OTHER_EDITIONS') }}
        </h3>
        <div class="rounded-lg border border-n-weak overflow-hidden">
          <table class="w-full">
            <thead>
              <tr class="bg-n-alpha-1 border-b border-n-weak">
                <th
                  class="text-left text-xs font-medium text-n-slate-11 px-4 py-2"
                >
                  {{ t('VOLT_EDITION_REPORTS.EDITION') }}
                </th>
                <th
                  class="text-right text-xs font-medium text-n-slate-11 px-4 py-2"
                >
                  {{ t('VOLT_EDITION_REPORTS.TICKETS') }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="edition in otherEditions"
                :key="edition.name"
                class="border-b border-n-weak last:border-0"
              >
                <td class="text-sm text-n-slate-12 px-4 py-2">
                  {{ edition.name }}
                </td>
                <td class="text-sm text-n-slate-12 text-right px-4 py-2">
                  {{ edition.count }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- Empty State -->
      <div
        v-if="reportData.editions.length === 0"
        class="text-center py-12 text-sm text-n-slate-11"
      >
        {{ t('VOLT_EDITION_REPORTS.EMPTY') }}
      </div>
    </template>
  </div>
</template>
