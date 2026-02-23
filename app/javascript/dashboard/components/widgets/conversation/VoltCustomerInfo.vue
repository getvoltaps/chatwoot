<script setup>
/* global axios */
import { ref, watch, computed } from 'vue';
import { useFunctionGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ContactInfoRow from 'dashboard/routes/dashboard/conversation/contact/ContactInfoRow.vue';

const props = defineProps({
  contactId: {
    type: [Number, String],
    required: true,
  },
});

const { t } = useI18n();
const contact = useFunctionGetter('contacts/getContact', props.contactId);

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
    const response = await axios.get(
      'https://api.getvolt.dk/v2/service/search',
      { params: { q: email.value } }
    );
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
      <ContactInfoRow
        :value="voltUser.id"
        icon="i-lucide-fingerprint"
        emoji="🪪"
        :title="t('CONVERSATION_SIDEBAR.VOLT.ID')"
        show-copy
      />
      <ContactInfoRow
        :value="voltUser.name"
        icon="i-lucide-user"
        emoji="👤"
        :title="t('CONVERSATION_SIDEBAR.VOLT.NAME')"
      />
      <ContactInfoRow
        :value="voltUser.email"
        :href="voltUser.email ? `mailto:${voltUser.email}` : ''"
        icon="i-lucide-mail"
        emoji="✉️"
        :title="t('CONVERSATION_SIDEBAR.VOLT.EMAIL')"
        show-copy
      />
      <ContactInfoRow
        :value="voltUser.phone"
        :href="voltUser.phone ? `tel:${voltUser.phone}` : ''"
        icon="i-lucide-phone"
        emoji="📞"
        :title="t('CONVERSATION_SIDEBAR.VOLT.PHONE')"
        show-copy
      />
    </div>
  </div>
</template>
