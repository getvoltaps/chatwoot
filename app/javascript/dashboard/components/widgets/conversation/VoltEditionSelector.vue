<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import MultiselectDropdown from 'shared/components/ui/MultiselectDropdown.vue';
import VoltAPI from 'dashboard/api/integrations/volt';

const CUSTOM_ATTR_KEY = 'volt_edition';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
});

const { t } = useI18n();
const store = useStore();

// Cache editions at module level so we only fetch once per session
let cachedEditions = null;

const editions = ref([]);
const loading = ref(false);

const currentChat = useMapGetter('getSelectedChat');

const currentEditionValue = computed(
  () => currentChat.value?.custom_attributes?.[CUSTOM_ATTR_KEY] || ''
);

const dropdownOptions = computed(() =>
  editions.value.map(edition => ({
    id: edition.id,
    name: `${edition.name} (${edition.abbreviation})`,
  }))
);

const selectedItem = computed(() => {
  if (!currentEditionValue.value) return {};
  const match = dropdownOptions.value.find(
    o => o.name === currentEditionValue.value
  );
  return match || { id: 0, name: currentEditionValue.value };
});

const fetchEditions = async () => {
  if (cachedEditions) {
    editions.value = cachedEditions;
    return;
  }
  try {
    loading.value = true;
    const response = await VoltAPI.getEditions();
    cachedEditions = response.data || [];
    editions.value = cachedEditions;
  } catch {
    // Silent fail — dropdown will just be empty
  } finally {
    loading.value = false;
  }
};

const onSelect = async item => {
  const customAttributes = {
    ...currentChat.value.custom_attributes,
    [CUSTOM_ATTR_KEY]: item.name,
  };
  await store.dispatch('updateCustomAttributes', {
    conversationId: props.conversationId,
    customAttributes,
  });
};

onMounted(fetchEditions);
</script>

<template>
  <div class="mb-1">
    <label class="text-xs font-medium text-n-slate-11 mb-1 block">
      {{ t('CONVERSATION_SIDEBAR.VOLT.EDITION') }}
    </label>
    <MultiselectDropdown
      :options="dropdownOptions"
      :selected-item="selectedItem"
      :has-thumbnail="false"
      :multiselect-placeholder="t('CONVERSATION_SIDEBAR.VOLT.SELECT_EDITION')"
      :input-placeholder="t('CONVERSATION_SIDEBAR.VOLT.SEARCH_EDITION')"
      :no-search-result="t('CONVERSATION_SIDEBAR.VOLT.NO_EDITION_FOUND')"
      @select="onSelect"
    />
  </div>
</template>
