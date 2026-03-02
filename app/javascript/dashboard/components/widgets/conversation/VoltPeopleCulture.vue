<script setup>
import { ref, computed, watch, toRef } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useFunctionGetter } from 'dashboard/composables/store';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import VoltAPI from 'dashboard/api/integrations/volt';
import VoltEditionSelector from './VoltEditionSelector.vue';

const CUSTOM_ATTR_KEY = 'volt_people_id';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
  contactId: {
    type: [Number, String],
    default: null,
  },
});

const { t } = useI18n();
const store = useStore();
const currentChat = useMapGetter('getSelectedChat');
const contact = useFunctionGetter('contacts/getContact', toRef(props, 'contactId'));
const email = computed(() => contact.value?.email);

// --- Member profile ---
const member = ref(null);
const memberLoading = ref(false);
const memberError = ref('');

const fetchMember = async () => {
  if (!email.value) return;
  try {
    memberLoading.value = true;
    memberError.value = '';
    member.value = null;
    const response = await VoltAPI.getMemberProfile(email.value);
    member.value = response.data;
  } catch (err) {
    if (err.response?.status !== 404) {
      memberError.value = t('CONVERSATION_SIDEBAR.VOLT_MEMBER.ERROR');
    }
  } finally {
    memberLoading.value = false;
  }
};

watch(
  () => email.value,
  val => { if (val) fetchMember(); },
  { immediate: true }
);

const statusColor = computed(() => {
  const s = member.value?.status?.toLowerCase() || '';
  if (s.includes('aktiv') && !s.includes('inaktiv')) return 'text-n-teal-11';
  if (s.includes('inaktiv') || s.includes('udgået')) return 'text-n-ruby-11';
  return 'text-n-slate-11';
});

// --- People ID custom attribute ---
const savedValue = computed(
  () => currentChat.value?.custom_attributes?.[CUSTOM_ATTR_KEY] || ''
);

const localValue = ref(savedValue.value);
const showSaved = ref(false);

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
  showSaved.value = true;
  setTimeout(() => {
    showSaved.value = false;
  }, 1500);
};
</script>

<template>
  <div class="px-4 py-2 text-n-slate-12 flex flex-col gap-1">
    <!-- Member profile section -->
    <div v-if="memberLoading" class="flex items-center justify-center py-2">
      <Spinner size="24" class="text-n-brand" />
    </div>
    <div v-else-if="memberError" class="text-xs text-n-ruby-11 mb-2">
      {{ memberError }}
    </div>
    <div v-else-if="member" class="flex flex-col gap-1.5 mb-3">
      <!-- Name (linked to profile) -->
      <a
        :href="member.profileUrl"
        target="_blank"
        rel="noopener noreferrer"
        class="text-sm font-medium text-n-brand hover:underline truncate"
        :title="member.name"
      >
        {{ member.name }}
      </a>

      <!-- Member type + status -->
      <div class="flex items-center gap-1.5 flex-wrap">
        <span v-if="member.memberType" class="text-xs text-n-slate-11">
          {{ member.memberType }}
        </span>
        <span
          v-if="member.status"
          class="text-xs font-medium"
          :class="statusColor"
        >
          &middot; {{ member.status }}
        </span>
      </div>

      <!-- Birthday -->
      <div v-if="member.birthday" class="flex items-center gap-1.5 text-xs text-n-slate-11">
        <span class="i-lucide-cake size-3.5 flex-shrink-0" />
        <span>{{ member.birthday }}</span>
      </div>

      <!-- Phone -->
      <div v-if="member.phone" class="flex items-center gap-1.5 text-xs text-n-slate-11">
        <span class="i-lucide-phone size-3.5 flex-shrink-0" />
        <a
          :href="`tel:${member.phone}`"
          class="hover:underline"
        >
          {{ member.phone }}
        </a>
      </div>

      <!-- Teams with payment status -->
      <div v-if="member.teams?.length" class="mt-1">
        <p class="text-xs font-medium text-n-slate-11 mb-1">
          {{ t('CONVERSATION_SIDEBAR.VOLT_MEMBER.TEAMS') }}
        </p>
        <div
          v-for="team in member.teams"
          :key="team.name"
          class="flex items-center justify-between py-0.5"
        >
          <span class="text-xs text-n-slate-12 truncate">{{ team.name }}</span>
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
    </div>
    <div v-else-if="email" class="text-xs text-n-slate-11 mb-2">
      {{ t('CONVERSATION_SIDEBAR.VOLT_MEMBER.NO_RESULTS') }}
    </div>

    <!-- People ID -->
    <div class="mb-1">
      <label class="text-xs font-medium text-n-slate-11 mb-1 flex items-center gap-1">
        {{ t('CONVERSATION_SIDEBAR.VOLT.PEOPLE_ID') }}
        <span
          v-if="showSaved"
          class="text-n-teal-11 text-xs transition-opacity"
        >
          Saved
        </span>
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
