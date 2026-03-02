<script setup>
import { ref, watch, computed, toRef } from 'vue';
import { useFunctionGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ContactInfoRow from 'dashboard/routes/dashboard/conversation/contact/ContactInfoRow.vue';
import VoltAPI from 'dashboard/api/integrations/volt';

const props = defineProps({
  contactId: {
    type: [Number, String],
    required: true,
  },
});

const { t } = useI18n();
const contact = useFunctionGetter('contacts/getContact', toRef(props, 'contactId'));
const email = computed(() => contact.value?.email);

const member = ref(null);
const loading = ref(false);
const error = ref('');

const fetchMemberProfile = async () => {
  if (!email.value) return;

  try {
    loading.value = true;
    error.value = '';
    member.value = null;
    const response = await VoltAPI.getMemberProfile(email.value);
    member.value = response.data;
  } catch (err) {
    if (err.response?.status === 404) {
      member.value = null;
    } else {
      error.value = t('CONVERSATION_SIDEBAR.VOLT_MEMBER.ERROR');
    }
  } finally {
    loading.value = false;
  }
};

watch(
  () => email.value,
  newEmail => {
    if (newEmail) fetchMemberProfile();
  },
  { immediate: true }
);

const statusColor = computed(() => {
  const s = member.value?.status?.toLowerCase() || '';
  if (s.includes('aktiv')) return 'text-n-teal-11';
  if (s.includes('inaktiv') || s.includes('udgået')) return 'text-n-ruby-11';
  return 'text-n-slate-11';
});
</script>

<template>
  <div class="px-4 py-2 text-n-slate-12">
    <div v-if="!email" class="text-sm text-n-slate-11">
      {{ t('CONVERSATION_SIDEBAR.VOLT_MEMBER.NO_EMAIL') }}
    </div>
    <div v-else-if="loading" class="flex items-center justify-center p-4">
      <Spinner size="32" class="text-n-brand" />
    </div>
    <div v-else-if="error" class="text-sm text-n-ruby-11">
      {{ error }}
    </div>
    <div v-else-if="!member" class="text-sm text-n-slate-11">
      {{ t('CONVERSATION_SIDEBAR.VOLT_MEMBER.NO_RESULTS') }}
    </div>
    <div v-else class="flex flex-col gap-1">
      <ContactInfoRow
        :value="member.name"
        icon="i-lucide-user"
        emoji=""
        :title="t('CONVERSATION_SIDEBAR.VOLT_MEMBER.NAME')"
      />
      <ContactInfoRow
        v-if="member.phone"
        :value="member.phone"
        :href="`tel:${member.phone}`"
        icon="i-lucide-phone"
        emoji=""
        :title="t('CONVERSATION_SIDEBAR.VOLT_MEMBER.PHONE')"
        show-copy
      />
      <ContactInfoRow
        v-if="member.email"
        :value="member.email"
        :href="`mailto:${member.email}`"
        icon="i-lucide-mail"
        emoji=""
        :title="t('CONVERSATION_SIDEBAR.VOLT_MEMBER.EMAIL')"
        show-copy
      />

      <!-- Status & type -->
      <div v-if="member.status" class="flex items-center gap-1.5 mt-1">
        <span class="text-xs font-medium" :class="statusColor">
          {{ member.status }}
        </span>
        <span v-if="member.memberType" class="text-xs text-n-slate-11">
          &middot; {{ member.memberType }}
        </span>
      </div>

      <!-- Birthday / Gender / Age -->
      <div
        v-if="member.birthday || member.genderAge"
        class="flex items-center gap-1.5 text-xs text-n-slate-11"
      >
        <span v-if="member.birthday">{{ member.birthday }}</span>
        <span v-if="member.birthday && member.genderAge">&middot;</span>
        <span v-if="member.genderAge">{{ member.genderAge }}</span>
      </div>

      <!-- Address -->
      <ContactInfoRow
        v-if="member.address"
        :value="member.address"
        icon="i-lucide-map-pin"
        emoji=""
        :title="t('CONVERSATION_SIDEBAR.VOLT_MEMBER.ADDRESS')"
      />

      <!-- Teams & payment -->
      <div v-if="member.teams?.length" class="mt-2">
        <p class="text-xs font-medium text-n-slate-11 mb-1">
          {{ t('CONVERSATION_SIDEBAR.VOLT_MEMBER.TEAMS') }}
        </p>
        <div
          v-for="team in member.teams"
          :key="team.name"
          class="flex items-center justify-between py-0.5"
        >
          <span class="text-sm text-n-slate-12 truncate">{{ team.name }}</span>
          <span
            v-if="team.paid !== null"
            class="flex-shrink-0 text-xs font-medium px-1.5 py-0.5 rounded"
            :class="team.paid ? 'bg-n-teal-3 text-n-teal-11' : 'bg-n-ruby-3 text-n-ruby-11'"
            :title="team.paymentTooltip || ''"
          >
            {{ team.paid ? t('CONVERSATION_SIDEBAR.VOLT_MEMBER.PAID') : t('CONVERSATION_SIDEBAR.VOLT_MEMBER.UNPAID') }}
          </span>
        </div>
      </div>

      <!-- Custom fields -->
      <div v-if="Object.keys(member.customFields || {}).length" class="mt-2">
        <p class="text-xs font-medium text-n-slate-11 mb-1">
          {{ t('CONVERSATION_SIDEBAR.VOLT_MEMBER.CUSTOM_FIELDS') }}
        </p>
        <div
          v-for="(value, key) in member.customFields"
          :key="key"
          class="flex items-center justify-between py-0.5 text-sm"
        >
          <span class="text-n-slate-11 truncate mr-2">{{ key }}</span>
          <span class="text-n-slate-12 truncate text-right">{{ value }}</span>
        </div>
      </div>

      <!-- Profile link -->
      <a
        :href="member.profileUrl"
        target="_blank"
        rel="noopener noreferrer"
        class="mt-2 text-xs text-n-brand hover:underline"
      >
        {{ t('CONVERSATION_SIDEBAR.VOLT_MEMBER.VIEW_PROFILE') }}
      </a>
    </div>
  </div>
</template>
