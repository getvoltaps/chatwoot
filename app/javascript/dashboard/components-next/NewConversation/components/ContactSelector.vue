<script setup>
import { computed, ref, nextTick } from 'vue';
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

// All chips to display (combines single selectedContact + selectedContacts)
const allSelectedContacts = computed(() => {
  if (props.selectedContacts.length > 0) return props.selectedContacts;
  if (props.selectedContact) return [props.selectedContact];
  return [];
});

const hasAnyContact = computed(() => allSelectedContacts.value.length > 0);

const getContactLabel = contact => {
  const { name, email = '', phoneNumber = '' } = contact || {};
  if (email) return `${name} (${email})`;
  if (phoneNumber) return `${name} (${phoneNumber})`;
  return name || '';
};

const errorClass = computed(() => {
  return props.hasErrors
    ? '[&_input]:placeholder:!text-n-ruby-9 [&_input]:dark:placeholder:!text-n-ruby-9'
    : '';
});

const handleInput = value => {
  inputType.value = value.startsWith('+') ? INPUT_TYPES.TEL : INPUT_TYPES.EMAIL;
  emit('searchContacts', value);
};

const handleAdd = event => {
  emit('setSelectedContact', event);
  // Reset the TagInput so it's ready for the next entry
  tagInputKey.value += 1;
};

const handleRemoveChip = contact => {
  if (props.selectedContacts.length > 0) {
    emit('removeContact', contact.id);
  } else {
    emit('clearSelectedContact');
  }
};

const handlePaste = event => {
  const pasted = event.clipboardData?.getData('text') || '';
  // Split on comma or semicolon
  const emails = pasted
    .split(/[,;]+/)
    .map(e => e.trim())
    .filter(e => e.length > 0);

  if (emails.length > 1) {
    event.preventDefault();
    emails.forEach(email => {
      emit('setSelectedContact', { value: email, action: 'create' });
    });
    nextTick(() => {
      tagInputKey.value += 1;
    });
  }
};
</script>

<template>
  <div class="relative flex-1 px-4 py-3 overflow-y-visible">
    <div class="flex items-start w-full gap-3 min-h-7">
      <label
        class="text-sm font-medium text-n-slate-11 whitespace-nowrap mt-1"
      >
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
      <div v-else class="flex flex-wrap items-center gap-1.5 flex-1">
        <div
          v-for="contact in allSelectedContacts"
          :key="contact.id"
          class="flex items-center gap-1.5 rounded-md bg-n-alpha-2 min-h-7 min-w-0 ltr:pl-3 rtl:pr-3 ltr:pr-1 rtl:pl-1"
        >
          <span class="text-sm truncate text-n-slate-12">
            {{ getContactLabel(contact) }}
          </span>
          <Button
            v-if="!contactId"
            variant="ghost"
            icon="i-lucide-x"
            color="slate"
            size="xs"
            @click="handleRemoveChip(contact)"
          />
        </div>
        <div
          class="flex-1 min-w-[200px]"
          @paste="handlePaste"
        >
          <TagInput
            :key="tagInputKey"
            :placeholder="
              hasAnyContact
                ? 'Add another recipient...'
                : t(`${i18nPrefix}.TAG_INPUT_PLACEHOLDER`)
            "
            mode="single"
            :menu-items="contactsList"
            :show-dropdown="showContactsDropdown"
            :is-loading="isLoading"
            allow-create
            :type="inputType"
            class="flex-1 min-h-7"
            :class="hasAnyContact ? '' : errorClass"
            :auto-open-dropdown="false"
            focus-on-mount
            @input="handleInput"
            @on-click-outside="emit('updateDropdown', 'contacts', false)"
            @add="handleAdd"
            @remove="() => {}"
          />
        </div>
      </div>
    </div>
  </div>
</template>
