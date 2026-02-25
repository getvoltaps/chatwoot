<script setup>
import { ref, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SectionLayout from '../account/components/SectionLayout.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import VoltAPI from 'dashboard/api/integrations/volt';

const { t } = useI18n();

const isLoading = ref(true);
const isBackfilling = ref(false);
const backfillMessage = ref('');
const stats = ref({
  indexed_conversations: 0,
  total_resolved_conversations: 0,
  coverage_percentage: 0,
  last_indexed_at: null,
  api_key_configured: false,
});

const fetchStats = async () => {
  isLoading.value = true;
  try {
    const { data } = await VoltAPI.getAiStats();
    stats.value = data;
  } catch {
    // silently fail
  } finally {
    isLoading.value = false;
  }
};

const startBackfill = async () => {
  isBackfilling.value = true;
  backfillMessage.value = '';
  try {
    const { data } = await VoltAPI.backfillAiConversations();
    backfillMessage.value = data.message;
    // Refresh stats after a short delay to allow some jobs to complete
    setTimeout(fetchStats, 3000);
  } catch {
    backfillMessage.value = 'Failed to start backfill. Please try again.';
  } finally {
    isBackfilling.value = false;
  }
};

const formatDate = dateStr => {
  if (!dateStr) return 'Never';
  return new Date(dateStr).toLocaleString();
};

onMounted(fetchStats);
</script>

<template>
  <SettingsLayout :is-loading="false">
    <template #header>
      <BaseSettingsHeader
        :title="t('VOLT_AI_SETTINGS.TITLE')"
        :description="t('VOLT_AI_SETTINGS.DESCRIPTION')"
      />
    </template>
    <template #body>
      <!-- Status Section -->
      <SectionLayout
        :title="t('VOLT_AI_SETTINGS.STATUS.TITLE')"
        :description="t('VOLT_AI_SETTINGS.STATUS.DESCRIPTION')"
      >
        <div v-if="isLoading" class="flex items-center gap-2 py-4">
          <Spinner :size="16" />
          <span class="text-sm text-n-slate-11">Loading...</span>
        </div>
        <div v-else class="grid grid-cols-2 gap-4 max-w-2xl">
          <!-- API Key Status -->
          <div class="rounded-lg border border-n-weak p-4">
            <div class="text-xs font-medium text-n-slate-11 mb-1">
              Anthropic API Key
            </div>
            <div class="flex items-center gap-2">
              <span
                class="size-2 rounded-full"
                :class="
                  stats.api_key_configured ? 'bg-n-green-9' : 'bg-n-red-9'
                "
              />
              <span class="text-sm text-n-slate-12">
                {{ stats.api_key_configured ? 'Configured' : 'Not set' }}
              </span>
            </div>
          </div>

          <!-- Indexed Conversations -->
          <div class="rounded-lg border border-n-weak p-4">
            <div class="text-xs font-medium text-n-slate-11 mb-1">
              Indexed Conversations
            </div>
            <span class="text-2xl font-semibold text-n-slate-12">
              {{ stats.indexed_conversations }}
            </span>
            <span class="text-sm text-n-slate-11 ml-1">
              / {{ stats.total_resolved_conversations }} resolved
            </span>
          </div>

          <!-- Coverage -->
          <div class="rounded-lg border border-n-weak p-4">
            <div class="text-xs font-medium text-n-slate-11 mb-1">
              Coverage
            </div>
            <div class="flex items-center gap-3">
              <div class="flex-1 h-2 rounded-full bg-n-weak overflow-hidden">
                <div
                  class="h-full rounded-full bg-n-green-9 transition-all"
                  :style="{ width: `${stats.coverage_percentage}%` }"
                />
              </div>
              <span class="text-sm font-medium text-n-slate-12">
                {{ stats.coverage_percentage }}%
              </span>
            </div>
          </div>

          <!-- Last Indexed -->
          <div class="rounded-lg border border-n-weak p-4">
            <div class="text-xs font-medium text-n-slate-11 mb-1">
              Last Indexed
            </div>
            <span class="text-sm text-n-slate-12">
              {{ formatDate(stats.last_indexed_at) }}
            </span>
          </div>
        </div>
      </SectionLayout>

      <!-- Backfill Section -->
      <SectionLayout
        :title="t('VOLT_AI_SETTINGS.BACKFILL.TITLE')"
        :description="t('VOLT_AI_SETTINGS.BACKFILL.DESCRIPTION')"
        with-border
      >
        <div class="flex items-center gap-4">
          <NextButton
            :label="t('VOLT_AI_SETTINGS.BACKFILL.BUTTON')"
            icon="i-lucide-database"
            variant="faded"
            color="blue"
            :is-loading="isBackfilling"
            @click="startBackfill"
          />
          <span
            v-if="backfillMessage"
            class="text-sm text-n-slate-11"
          >
            {{ backfillMessage }}
          </span>
        </div>
      </SectionLayout>

      <!-- How It Works Section -->
      <SectionLayout
        :title="t('VOLT_AI_SETTINGS.HOW_IT_WORKS.TITLE')"
        :description="t('VOLT_AI_SETTINGS.HOW_IT_WORKS.DESCRIPTION')"
        with-border
      >
        <div class="max-w-2xl space-y-3">
          <div class="flex gap-3 items-start">
            <span class="i-lucide-message-square text-n-slate-11 text-lg flex-shrink-0 mt-0.5" />
            <div>
              <div class="text-sm font-medium text-n-slate-12">
                {{ t('VOLT_AI_SETTINGS.HOW_IT_WORKS.STEP_1_TITLE') }}
              </div>
              <div class="text-sm text-n-slate-11">
                {{ t('VOLT_AI_SETTINGS.HOW_IT_WORKS.STEP_1_DESC') }}
              </div>
            </div>
          </div>
          <div class="flex gap-3 items-start">
            <span class="i-lucide-search text-n-slate-11 text-lg flex-shrink-0 mt-0.5" />
            <div>
              <div class="text-sm font-medium text-n-slate-12">
                {{ t('VOLT_AI_SETTINGS.HOW_IT_WORKS.STEP_2_TITLE') }}
              </div>
              <div class="text-sm text-n-slate-11">
                {{ t('VOLT_AI_SETTINGS.HOW_IT_WORKS.STEP_2_DESC') }}
              </div>
            </div>
          </div>
          <div class="flex gap-3 items-start">
            <span class="i-ph-sparkle-fill text-n-slate-11 text-lg flex-shrink-0 mt-0.5" />
            <div>
              <div class="text-sm font-medium text-n-slate-12">
                {{ t('VOLT_AI_SETTINGS.HOW_IT_WORKS.STEP_3_TITLE') }}
              </div>
              <div class="text-sm text-n-slate-11">
                {{ t('VOLT_AI_SETTINGS.HOW_IT_WORKS.STEP_3_DESC') }}
              </div>
            </div>
          </div>
        </div>
      </SectionLayout>
    </template>
  </SettingsLayout>
</template>
