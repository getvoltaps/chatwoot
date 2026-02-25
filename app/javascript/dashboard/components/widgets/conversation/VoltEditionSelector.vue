<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import VoltAPI from 'dashboard/api/integrations/volt';
import VoltAttributeSelector from './VoltAttributeSelector.vue';

defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
});

const { t } = useI18n();

let cachedEditions = null;
const editions = ref([]);

const editionOptions = computed(() =>
  editions.value.map(edition => ({
    id: edition.id,
    name: `${edition.name} (${edition.abbreviation})`,
  }))
);

const fetchEditions = async () => {
  if (cachedEditions) {
    editions.value = cachedEditions;
    return;
  }
  try {
    const response = await VoltAPI.getEditions();
    cachedEditions = response.data || [];
    editions.value = cachedEditions;
  } catch {
    // Silent fail — dropdown will just be empty
  }
};

onMounted(fetchEditions);
</script>

<template>
  <VoltAttributeSelector
    :conversation-id="conversationId"
    attribute-key="volt_edition"
    :label="t('CONVERSATION_SIDEBAR.VOLT.EDITION')"
    :placeholder="t('CONVERSATION_SIDEBAR.VOLT.SELECT_EDITION')"
    :search-placeholder="t('CONVERSATION_SIDEBAR.VOLT.SEARCH_EDITION')"
    :no-result-text="t('CONVERSATION_SIDEBAR.VOLT.NO_EDITION_FOUND')"
    :options="editionOptions"
  />
</template>
