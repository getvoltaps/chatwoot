<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import VoltEditionSelector from './VoltEditionSelector.vue';

const CUSTOM_ATTR_KEY = 'volt_people_id';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
});

const { t } = useI18n();
const store = useStore();
const currentChat = useMapGetter('getSelectedChat');

const savedValue = computed(
  () => currentChat.value?.custom_attributes?.[CUSTOM_ATTR_KEY] || ''
);

const localValue = ref(savedValue.value);

watch(savedValue, val => {
  localValue.value = val;
});

const savePeopleId = async () => {
  if (localValue.value === savedValue.value) return;

  const customAttributes = {
    ...currentChat.value.custom_attributes,
    [CUSTOM_ATTR_KEY]: localValue.value,
  };
  await store.dispatch('updateCustomAttributes', {
    conversationId: props.conversationId,
    customAttributes,
  });
};
</script>

<template>
  <div class="px-4 py-2 text-n-slate-12 flex flex-col gap-1">
    <div class="mb-1">
      <label class="text-xs font-medium text-n-slate-11 mb-1 block">
        {{ t('CONVERSATION_SIDEBAR.VOLT.PEOPLE_ID') }}
      </label>
      <input
        v-model="localValue"
        type="text"
        class="w-full rounded-md border border-n-weak bg-n-background px-2 py-1.5 text-sm text-n-slate-12 placeholder:text-n-slate-11 focus:border-n-brand focus:outline-none"
        :placeholder="t('CONVERSATION_SIDEBAR.VOLT.PEOPLE_ID_PLACEHOLDER')"
        @blur="savePeopleId"
        @keydown.enter="savePeopleId"
      />
    </div>
    <VoltEditionSelector :conversation-id="conversationId" />
  </div>
</template>
