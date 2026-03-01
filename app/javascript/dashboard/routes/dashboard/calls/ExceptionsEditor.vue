<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  exceptions: {
    type: Object,
    default: () => ({}),
  },
  readonly: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['update']);
const { t } = useI18n();

const newDate = ref('');
const newClosed = ref(false);
const newFrom = ref('09:00');
const newTo = ref('17:00');

const sortedDates = () => {
  return Object.keys(props.exceptions).sort();
};

const formatDate = dateStr => {
  return new Date(dateStr).toLocaleDateString('en-GB', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  });
};

const formatRanges = ranges => {
  if (!ranges || ranges.length === 0) return t('CALLS.OPENING_HOURS.CLOSED');
  return ranges.map(r => `${r[0]}–${r[1]}`).join(', ');
};

const addException = () => {
  if (!newDate.value) return;
  const updated = { ...props.exceptions };
  updated[newDate.value] = newClosed.value ? [] : [[newFrom.value, newTo.value]];
  emit('update', updated);
  newDate.value = '';
  newClosed.value = false;
  newFrom.value = '09:00';
  newTo.value = '17:00';
};

const removeException = date => {
  const updated = { ...props.exceptions };
  delete updated[date];
  emit('update', updated);
};
</script>

<template>
  <div class="mt-6">
    <h3 class="text-sm font-semibold text-n-slate-12 mb-1">
      {{ t('CALLS.OPENING_HOURS.EXCEPTIONS.TITLE') }}
    </h3>
    <p class="text-xs text-n-slate-11 mb-3">
      {{ t('CALLS.OPENING_HOURS.EXCEPTIONS.DESCRIPTION') }}
    </p>

    <div v-if="sortedDates().length === 0 && readonly" class="text-sm text-n-slate-11 py-2">
      {{ t('CALLS.OPENING_HOURS.EXCEPTIONS.EMPTY') }}
    </div>

    <div v-if="sortedDates().length > 0" class="flex flex-col gap-2 mb-3">
      <div
        v-for="date in sortedDates()"
        :key="date"
        class="flex items-center justify-between rounded-lg bg-n-alpha-1 px-3 py-2"
      >
        <div class="flex items-center gap-3">
          <span class="text-sm font-medium text-n-slate-12">
            {{ formatDate(date) }}
          </span>
          <span class="text-sm text-n-slate-11">
            {{ formatRanges(exceptions[date]) }}
          </span>
        </div>
        <Button
          v-if="!readonly"
          xs
          ghost
          class="text-n-slate-11 hover:enabled:text-n-ruby-11"
          icon="i-lucide-x"
          @click="removeException(date)"
        />
      </div>
    </div>

    <div v-if="!readonly" class="flex items-center gap-2 flex-wrap">
      <input
        v-model="newDate"
        type="date"
        class="rounded-lg border border-n-weak bg-n-alpha-black2 px-2 py-1.5 text-sm text-n-slate-12"
      />
      <label class="flex items-center gap-1.5 text-sm text-n-slate-12">
        <input v-model="newClosed" type="checkbox" class="m-0" />
        {{ t('CALLS.OPENING_HOURS.EXCEPTIONS.CLOSED_ALL_DAY') }}
      </label>
      <template v-if="!newClosed">
        <input
          v-model="newFrom"
          type="time"
          class="rounded-lg border border-n-weak bg-n-alpha-black2 px-2 py-1.5 text-sm text-n-slate-12"
        />
        <span class="text-n-slate-11">—</span>
        <input
          v-model="newTo"
          type="time"
          class="rounded-lg border border-n-weak bg-n-alpha-black2 px-2 py-1.5 text-sm text-n-slate-12"
        />
      </template>
      <Button
        xs
        faded
        color="blue"
        :label="t('CALLS.OPENING_HOURS.EXCEPTIONS.ADD')"
        icon="i-lucide-plus"
        :disabled="!newDate"
        @click="addException"
      />
    </div>
  </div>
</template>
