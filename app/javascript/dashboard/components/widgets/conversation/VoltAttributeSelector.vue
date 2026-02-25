<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import MultiselectDropdown from 'shared/components/ui/MultiselectDropdown.vue';

const NONE_OPTION = { id: '__none__', name: '— None —' };

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
  attributeKey: {
    type: String,
    required: true,
  },
  label: {
    type: String,
    required: true,
  },
  placeholder: {
    type: String,
    default: 'Select...',
  },
  searchPlaceholder: {
    type: String,
    default: 'Search...',
  },
  noResultText: {
    type: String,
    default: 'No results found',
  },
  options: {
    type: Array,
    default: () => [],
  },
});

const { t } = useI18n();
const store = useStore();
const currentChat = useMapGetter('getSelectedChat');

const currentValue = computed(
  () => currentChat.value?.custom_attributes?.[props.attributeKey] || ''
);

const dropdownOptions = computed(() => {
  const opts = [...props.options];
  if (currentValue.value) {
    opts.unshift(NONE_OPTION);
  }
  return opts;
});

const selectedItem = computed(() => {
  if (!currentValue.value) return {};
  const match = props.options.find(o => o.name === currentValue.value);
  return match || { id: 0, name: currentValue.value };
});

const onSelect = async item => {
  const value = item.id === '__none__' ? '' : item.name;
  const customAttributes = {
    ...currentChat.value.custom_attributes,
    [props.attributeKey]: value,
  };
  await store.dispatch('updateCustomAttributes', {
    conversationId: props.conversationId,
    customAttributes,
  });
};
</script>

<template>
  <div class="mb-1">
    <label class="text-xs font-medium text-n-slate-11 mb-1 block">
      {{ label }}
    </label>
    <MultiselectDropdown
      :options="dropdownOptions"
      :selected-item="selectedItem"
      :has-thumbnail="false"
      :multiselect-placeholder="placeholder"
      :input-placeholder="searchPlaceholder"
      :no-search-result="noResultText"
      @select="onSelect"
    />
  </div>
</template>
