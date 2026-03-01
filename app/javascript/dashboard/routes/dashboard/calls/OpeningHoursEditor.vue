<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';

const DAY_KEYS = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

const props = defineProps({
  schedule: {
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

const days = computed(() =>
  DAY_KEYS.map(key => ({
    key,
    label: t(`CALLS.OPENING_HOURS.DAYS.${key}`),
    ranges: props.schedule[key] || [],
  }))
);

const updateDay = (dayKey, ranges) => {
  emit('update', { ...props.schedule, [dayKey]: ranges });
};

const toggleDay = (dayKey, enabled) => {
  if (enabled) {
    updateDay(dayKey, [['09:00', '17:00']]);
  } else {
    updateDay(dayKey, []);
  }
};

const updateRange = (dayKey, rangeIndex, field, value) => {
  const ranges = [...(props.schedule[dayKey] || [])];
  ranges[rangeIndex] = [...ranges[rangeIndex]];
  ranges[rangeIndex][field === 'from' ? 0 : 1] = value;
  updateDay(dayKey, ranges);
};

const addRange = dayKey => {
  const ranges = [...(props.schedule[dayKey] || [])];
  ranges.push(['09:00', '17:00']);
  updateDay(dayKey, ranges);
};

const removeRange = (dayKey, rangeIndex) => {
  const ranges = [...(props.schedule[dayKey] || [])];
  ranges.splice(rangeIndex, 1);
  updateDay(dayKey, ranges);
};
</script>

<template>
  <div>
    <table
      class="min-w-full table-auto outline outline-1 -outline-offset-1 outline-n-weak rounded-xl"
    >
      <thead>
        <tr class="border-b border-n-weak">
          <th
            class="py-3 ltr:pl-4 ltr:pr-3 rtl:pl-3 rtl:pr-4 text-start text-heading-3 text-n-slate-12 w-36"
          >
            Day
          </th>
          <th
            class="py-3 ltr:pr-3 rtl:pl-3 text-start text-heading-3 text-n-slate-12"
          >
            Hours
          </th>
        </tr>
      </thead>
      <tbody class="divide-y divide-n-weak">
        <tr v-for="day in days" :key="day.key">
          <td class="ltr:pl-4 ltr:pr-3 rtl:pl-3 rtl:pr-4 py-3">
            <div class="flex items-center gap-2">
              <input
                v-if="!readonly"
                type="checkbox"
                class="m-0"
                :checked="day.ranges.length > 0"
                @change="toggleDay(day.key, $event.target.checked)"
              />
              <span class="text-body-main text-n-slate-12 font-medium">
                {{ day.label }}
              </span>
            </div>
          </td>
          <td class="py-3 ltr:pr-3 rtl:pl-3">
            <div v-if="day.ranges.length === 0" class="text-body-main text-n-slate-11">
              {{ t('CALLS.OPENING_HOURS.CLOSED') }}
            </div>
            <div v-else class="flex flex-col gap-2">
              <div
                v-for="(range, ri) in day.ranges"
                :key="ri"
                class="flex items-center gap-2"
              >
                <input
                  type="time"
                  :value="range[0]"
                  :disabled="readonly"
                  class="rounded-lg border border-n-weak bg-n-alpha-black2 px-2 py-1.5 text-sm text-n-slate-12 disabled:opacity-50"
                  @input="updateRange(day.key, ri, 'from', $event.target.value)"
                />
                <span class="text-n-slate-11">—</span>
                <input
                  type="time"
                  :value="range[1]"
                  :disabled="readonly"
                  class="rounded-lg border border-n-weak bg-n-alpha-black2 px-2 py-1.5 text-sm text-n-slate-12 disabled:opacity-50"
                  @input="updateRange(day.key, ri, 'to', $event.target.value)"
                />
                <Button
                  v-if="!readonly && day.ranges.length > 1"
                  xs
                  ghost
                  class="text-n-slate-11 hover:enabled:text-n-ruby-11"
                  icon="i-lucide-x"
                  @click="removeRange(day.key, ri)"
                />
              </div>
              <Button
                v-if="!readonly"
                xs
                faded
                slate
                :label="t('CALLS.OPENING_HOURS.ADD_RANGE')"
                icon="i-lucide-plus"
                @click="addRange(day.key)"
              />
            </div>
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>
