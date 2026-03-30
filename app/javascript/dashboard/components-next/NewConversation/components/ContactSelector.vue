<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { INPUT_TYPES } from 'dashboard/components-next/taginput/helper/tagInputHelper.js';

import TagInput from 'dashboard/components-next/taginput/TagInput.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  contacts: {
    type: Array,
    required: true,
  },
  selectedContact: {
    type: Object,
    default: null,
  },
  selectedContacts: {
    type: Array,
    default: () => [],
  },
  showContactsDropdown: {
    type: Boolean,
    required: true,
  },
  isLoading: {
    type: Boolean,
    required: true,
  },
  isCreatingContact: {
    type: Boolean,
    required: true,
  },
  contactId: {
    type: String,
    default: null,
  },
  contactableInboxesList: {
    type: Array,
    default: () => [],
  },
  showInboxesDropdown: {
    type: Boolean,
    required: true,
  },
  hasErrors: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits([
  'searchContacts',
  'setSelectedContact',
  'clearSelectedContact',
  'removeContact',
  'updateDropdown',
]);

const i18nPrefix = 'COMPOSE_NEW_CONVERSATION.FORM.CONTACT_SELECTOR';
const { t } = useI18n();

const inputType = ref(INPUT_TYPES.EMAIL);
const tagInputKey = ref(0);

const contactsList = computed(() => {
  const selectedIds = new Set(props.selectedContacts.map(c => c.id));
  if (props.selectedContact) selectedIds.add(props.selectedContact.id);

  return props.contacts
    ?.filter(({ id }) => !selectedIds.has(id))
    .map(({ name, id, thumbnail, email, ...rest }) => ({
      id,
      label: email ? `${name} (${email})` : name,
      value: id,
      thumbnail: { name, src: thumbnail },
      ...rest,
      name,
      email,
      action: 'contact',
    }));
});

const isMultiMode = computed(() => props.selectedContacts.length > 0);

const getContactLabel = contact => {
  const { name, email = '', phoneNumber = '' } = contact || {};
  if (email) return `${name} (${email})`;
  if (phoneNumber) return `${name} (${phoneNumber})`;
  return name || '';
};

const selectedContactLabel = computed(() => {
  return getContactLabel(props.selectedContact);
});

const errorClass = computed(() => {
  return props.hasErrors
    ? '[&_input]:placeholder:!text-n-ruby-9 [&_input]:dark:placeholder:!text-n-ruby-9'
    : '';
});

const handleInput = value => {
  // Update input type based on whether input starts with '+'
  // If it does, set input type to 'tel'
  // Otherwise, set input type to 'email'
  inputType.value = value.startsWith('+') ? INPUT_TYPES.TEL : INPUT_TYPES.EMAIL;
  emit('searchContacts', value);
};

const handleMultiAdd = event => {
  emit('setSelectedContact', event);
  // Reset the TagInput by changing its key so it remounts fresh
  tagInputKey.value += 1;
};
</script>

<template>
  <div class="relative flex-1 px-4 py-3 overflow-y-visible">
    <div class="flex items-baseline w-full gap-3 min-h-7">
      <label class="text-sm font-medium text-n-slate-11 whitespace-nowrap">
        {{ t(`${i18nPrefix}.LABEL`) }}
      </label>

      <div
        v-if="isCreatingContact"
        class="flex items-center gap-1.5 rounded-md bg-n-alpha-2 px-3 min-h-7 min-w-0"
      >
        <span class="text-sm truncate text-n-slate-12">
          {{ t(`${i18nPrefix}.CONTACT_CREATING`) }}
        </span>
      </div>
      <template v-else-if="isMultiMode">
        <div class="flex flex-wrap items-center gap-1.5 flex-1">
          <div
            v-for="contact in selectedContacts"
            :key="contact.id"
            class="flex items-center gap-1.5 rounded-md bg-n-alpha-2 min-h-7 min-w-0 ltr:pl-3 rtl:pr-3 ltr:pr-1 rtl:pl-1"
          >
            <span class="text-sm truncate text-n-slate-12">
              {{ getContactLabel(contact) }}
            </span>
            <Button
              variant="ghost"
              icon="i-lucide-x"
              color="slate"
              size="xs"
              @click="emit('removeContact', contact.id)"
            />
          </div>
          <TagInput
            :key="tagInputKey"
            :placeholder="t(`${i18nPrefix}.TAG_INPUT_PLACEHOLDER`)"
            mode="single"
            :menu-items="contactsList"
            :show-dropdown="showContactsDropdown"
            :is-loading="isLoading"
            allow-create
            :type="inputType"
            class="flex-1 min-h-7 min-w-[200px]"
            :auto-open-dropdown="false"
            focus-on-mount
            @input="handleInput"
            @on-click-outside="emit('updateDropdown', 'contacts', false)"
            @add="handleMultiAdd"
            @remove="() => {}"
          />
        </div>
      </template>
      <div
        v-else-if="selectedContact"
        class="flex items-center gap-1.5 rounded-md bg-n-alpha-2 min-h-7 min-w-0"
        :class="!contactId ? 'ltr:pl-3 rtl:pr-3 ltr:pr-1 rtl:pl-1' : 'px-3'"
      >
        <span class="text-sm truncate text-n-slate-12">
          {{
            isCreatingContact
              ? t(`${i18nPrefix}.CONTACT_CREATING`)
              : selectedContactLabel
          }}
        </span>
        <Button
          v-if="!contactId"
          variant="ghost"
          icon="i-lucide-x"
          color="slate"
          :disabled="contactId"
          size="xs"
          @click="emit('clearSelectedContact')"
        />
      </div>
      <TagInput
        v-else
        :placeholder="t(`${i18nPrefix}.TAG_INPUT_PLACEHOLDER`)"
        mode="single"
        :menu-items="contactsList"
        :show-dropdown="showContactsDropdown"
        :is-loading="isLoading"
        :disabled="contactableInboxesList?.length > 0 && showInboxesDropdown"
        allow-create
        :type="inputType"
        class="flex-1 min-h-7"
        :class="errorClass"
        focus-on-mount
        @input="handleInput"
        @on-click-outside="emit('updateDropdown', 'contacts', false)"
        @add="emit('setSelectedContact', $event)"
        @remove="emit('clearSelectedContact')"
      />
    </div>
  </div>
</template>
