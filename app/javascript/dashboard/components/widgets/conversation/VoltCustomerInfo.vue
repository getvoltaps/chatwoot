<script setup>
import { ref, watch, computed, toRef } from 'vue';
import { useFunctionGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ContactInfoRow from 'dashboard/routes/dashboard/conversation/contact/ContactInfoRow.vue';
import VoltAPI from 'dashboard/api/integrations/volt';
import VoltEditionSelector from './VoltEditionSelector.vue';
import VoltAttributeSelector from './VoltAttributeSelector.vue';

const PRODUCT_OPTIONS = [
  { id: 1, name: 'Volt Charging' },
  { id: 2, name: 'Brick Charging' },
  { id: 3, name: 'Locker' },
  { id: 4, name: 'Cool Locker' },
  { id: 5, name: 'Soundboks' },
  { id: 6, name: 'Soundlock' },
  { id: 7, name: 'Other products' },
];

const SUBJECT_OPTIONS = [
  { id: 1, name: 'Order confirmation' },
  { id: 2, name: 'Deposits' },
  { id: 3, name: 'Changes to order' },
  { id: 4, name: 'Cancellation' },
  { id: 5, name: 'Problems on-site' },
  { id: 6, name: 'Complaints' },
  { id: 7, name: 'Technical issues' },
  { id: 8, name: 'Sales lead' },
  { id: 9, name: 'General / Other' },
];

const props = defineProps({
  contactId: {
    type: [Number, String],
    required: true,
  },
  conversationId: {
    type: [Number, String],
    required: true,
  },
});

const { t } = useI18n();
const contact = useFunctionGetter('contacts/getContact', toRef(props, 'contactId'));

const email = computed(() => contact.value?.email);

const voltUser = ref(null);
const loading = ref(false);
const error = ref('');

const fetchVoltCustomer = async () => {
  if (!email.value) return;

  try {
    loading.value = true;
    error.value = '';
    voltUser.value = null;
    const response = await VoltAPI.search(email.value);
    const users = response.data?.users || [];
    voltUser.value = users.length ? users[0] : null;
  } catch {
    error.value = t('CONVERSATION_SIDEBAR.VOLT.ERROR');
  } finally {
    loading.value = false;
  }
};

watch(
  () => email.value,
  newEmail => {
    if (newEmail) fetchVoltCustomer();
  },
  { immediate: true }
);
</script>

<template>
  <div class="px-4 py-2 text-n-slate-12">
    <div v-if="!email" class="text-sm text-n-slate-11">
      {{ t('CONVERSATION_SIDEBAR.VOLT.NO_EMAIL') }}
    </div>
    <div v-else-if="loading" class="flex items-center justify-center p-4">
      <Spinner size="32" class="text-n-brand" />
    </div>
    <div v-else-if="error" class="text-sm text-n-ruby-11">
      {{ error }}
    </div>
    <div v-else-if="!voltUser" class="text-sm text-n-slate-11">
      {{ t('CONVERSATION_SIDEBAR.VOLT.NO_RESULTS') }}
    </div>
    <div v-else class="flex flex-col gap-1">
      <!-- Hidden ID for debugging -->
      <span v-if="voltUser.id" class="hidden" :data-volt-id="voltUser.id" />
      <ContactInfoRow
        :value="voltUser.name"
        icon="i-lucide-user"
        emoji=""
        :title="t('CONVERSATION_SIDEBAR.VOLT.NAME')"
      />
      <ContactInfoRow
        :value="voltUser.email"
        :href="voltUser.email ? `mailto:${voltUser.email}` : ''"
        icon="i-lucide-mail"
        emoji=""
        :title="t('CONVERSATION_SIDEBAR.VOLT.EMAIL')"
        show-copy
      />
      <ContactInfoRow
        :value="voltUser.phone"
        :href="voltUser.phone ? `tel:${voltUser.phone}` : ''"
        icon="i-lucide-phone"
        emoji=""
        :title="t('CONVERSATION_SIDEBAR.VOLT.PHONE')"
        show-copy
      />
    </div>
    <div class="mt-3 flex flex-col gap-1">
      <VoltEditionSelector :conversation-id="conversationId" />
      <VoltAttributeSelector
        :conversation-id="conversationId"
        attribute-key="volt_product"
        :label="t('CONVERSATION_SIDEBAR.VOLT.PRODUCT')"
        :placeholder="t('CONVERSATION_SIDEBAR.VOLT.SELECT_PRODUCT')"
        :search-placeholder="t('CONVERSATION_SIDEBAR.VOLT.SEARCH_PRODUCT')"
        :no-result-text="t('CONVERSATION_SIDEBAR.VOLT.NO_PRODUCT_FOUND')"
        :options="PRODUCT_OPTIONS"
      />
      <VoltAttributeSelector
        :conversation-id="conversationId"
        attribute-key="volt_subject"
        :label="t('CONVERSATION_SIDEBAR.VOLT.SUBJECT')"
        :placeholder="t('CONVERSATION_SIDEBAR.VOLT.SELECT_SUBJECT')"
        :search-placeholder="t('CONVERSATION_SIDEBAR.VOLT.SEARCH_SUBJECT')"
        :no-result-text="t('CONVERSATION_SIDEBAR.VOLT.NO_SUBJECT_FOUND')"
        :options="SUBJECT_OPTIONS"
      />
    </div>
  </div>
</template>
