# Move Conversation Between Email Inboxes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let agents move an open conversation from one email inbox to another (e.g. `support@` → `eventstaff@`), so future agent replies are sent from the target inbox and customer replies route there.

**Architecture:** A new `Conversations::MoveToInboxService` updates `conversation.inbox_id`, repoints `contact_inbox_id` (reusing `ContactInboxBuilder` for find-or-create), migrates message `inbox_id`s, and logs an activity message — all in one transaction. A new `move_to_inbox` controller action exposes it. The frontend adds a "Move to inbox" item to the existing Resolve dropdown that opens a modal listing email inboxes. No mailer changes are needed because outgoing From/Reply-To/SMTP already resolve from `conversation.inbox` at send time.

**Tech Stack:** Rails (service object, controller, routes, RSpec), Vue 3 `<script setup>` + Vuex, Tailwind.

---

## File Structure

**Backend (create):**
- `app/services/conversations/move_to_inbox_service.rb` — core move logic.
- `spec/services/conversations/move_to_inbox_service_spec.rb` — the one backend spec.

**Backend (modify):**
- `config/routes.rb:148-161` — add `post :move_to_inbox` member route.
- `app/controllers/api/v1/accounts/conversations_controller.rb` — add `move_to_inbox` action.
- `config/locales/en.yml` — activity message string + error strings.

**Frontend (create):**
- `app/javascript/dashboard/components-next/ConversationWorkflow/MoveToInboxModal.vue` — modal with email-inbox selector.

**Frontend (modify):**
- `app/javascript/dashboard/api/inbox/conversation.js` — add `moveToInbox` API method.
- `app/javascript/dashboard/store/modules/conversations/actions.js` — add `moveConversationToInbox` action.
- `app/javascript/dashboard/components/buttons/ResolveAction.vue` — add dropdown item + wire modal.
- `app/javascript/dashboard/i18n/locale/en/conversation.json` — frontend strings.

---

## Task 1: Backend service — `Conversations::MoveToInboxService`

**Files:**
- Create: `app/services/conversations/move_to_inbox_service.rb`
- Test: `spec/services/conversations/move_to_inbox_service_spec.rb`

- [ ] **Step 1: Write the failing spec**

Create `spec/services/conversations/move_to_inbox_service_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe Conversations::MoveToInboxService do
  let(:account) { create(:account) }
  let(:source_inbox) { create(:inbox, account: account) } # default factory is email channel
  let(:target_inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account, email: 'customer@example.com') }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: source_inbox, source_id: contact.email) }
  let(:conversation) do
    create(:conversation, account: account, inbox: source_inbox, contact: contact, contact_inbox: contact_inbox)
  end

  describe '#perform' do
    it 'moves the conversation to the target inbox' do
      described_class.new(conversation: conversation, target_inbox: target_inbox).perform
      expect(conversation.reload.inbox_id).to eq(target_inbox.id)
    end

    it 'repoints contact_inbox to one belonging to the target inbox' do
      described_class.new(conversation: conversation, target_inbox: target_inbox).perform
      expect(conversation.reload.contact_inbox.inbox_id).to eq(target_inbox.id)
      expect(conversation.contact_inbox.source_id).to eq(contact.email)
    end

    it 'migrates existing message inbox_ids to the target inbox' do
      create(:message, account: account, inbox: source_inbox, conversation: conversation)
      described_class.new(conversation: conversation, target_inbox: target_inbox).perform
      expect(conversation.reload.messages.where.not(inbox_id: target_inbox.id)).to be_empty
    end

    it 'creates an activity message recording the move' do
      expect do
        described_class.new(conversation: conversation, target_inbox: target_inbox).perform
      end.to change { conversation.messages.where(message_type: :activity).count }.by(1)
    end

    it 'raises when target inbox is in a different account' do
      other_inbox = create(:inbox, account: create(:account))
      expect do
        described_class.new(conversation: conversation, target_inbox: other_inbox).perform
      end.to raise_error(StandardError)
    end

    it 'raises when target inbox equals the current inbox' do
      expect do
        described_class.new(conversation: conversation, target_inbox: source_inbox).perform
      end.to raise_error(StandardError)
    end

    it 'raises when target inbox is not an email inbox' do
      web_inbox = create(:inbox, account: account, channel: create(:channel_widget, account: account))
      expect do
        described_class.new(conversation: conversation, target_inbox: web_inbox).perform
      end.to raise_error(StandardError)
    end
  end
end
```

- [ ] **Step 2: Run the spec to verify it fails**

Run: `eval "$(rbenv init -)"; bundle exec rspec spec/services/conversations/move_to_inbox_service_spec.rb`
Expected: FAIL with `uninitialized constant Conversations::MoveToInboxService`.

- [ ] **Step 3: Write the service**

Create `app/services/conversations/move_to_inbox_service.rb`:

```ruby
class Conversations::MoveToInboxService
  pattr_initialize [:conversation!, :target_inbox!]

  def perform
    validate!

    ActiveRecord::Base.transaction do
      target_contact_inbox = build_contact_inbox
      migrate_conversation(target_contact_inbox)
      migrate_messages
      log_activity
    end

    conversation
  end

  private

  def validate!
    raise StandardError, 'Target inbox not in account' if target_inbox.account_id != conversation.account_id
    raise StandardError, 'Already in this inbox' if target_inbox.id == conversation.inbox_id
    raise StandardError, 'Only email inboxes are supported' unless target_inbox.channel_type == 'Channel::Email'
    raise StandardError, 'Contact has no email' if conversation.contact.email.blank?
  end

  def build_contact_inbox
    ContactInboxBuilder.new(
      contact: conversation.contact,
      inbox: target_inbox,
      source_id: conversation.contact.email
    ).perform
  end

  def migrate_conversation(target_contact_inbox)
    conversation.update!(inbox_id: target_inbox.id, contact_inbox_id: target_contact_inbox.id)
  end

  def migrate_messages
    # rubocop:disable Rails/SkipsModelValidations
    conversation.messages.update_all(inbox_id: target_inbox.id)
    # rubocop:enable Rails/SkipsModelValidations
  end

  def log_activity
    content = I18n.t(
      'conversations.activity.moved_to_inbox',
      user_name: Current.user&.name || 'System',
      inbox_name: target_inbox.name
    )
    conversation.messages.create!(
      account_id: conversation.account_id,
      inbox_id: target_inbox.id,
      message_type: :activity,
      content: content
    )
  end
end
```

- [ ] **Step 4: Add the activity i18n string**

In `config/locales/en.yml`, under `en.conversations.activity` (find the existing `status:` block and add a sibling key), add:

```yaml
      moved_to_inbox: "%{user_name} moved the conversation to %{inbox_name}"
```

- [ ] **Step 5: Run the spec to verify it passes**

Run: `eval "$(rbenv init -)"; bundle exec rspec spec/services/conversations/move_to_inbox_service_spec.rb`
Expected: PASS (all examples green).

- [ ] **Step 6: Lint**

Run: `eval "$(rbenv init -)"; bundle exec rubocop -a app/services/conversations/move_to_inbox_service_spec.rb app/services/conversations/move_to_inbox_service.rb`
Expected: no offenses.

- [ ] **Step 7: Commit**

```bash
git add app/services/conversations/move_to_inbox_service.rb spec/services/conversations/move_to_inbox_service_spec.rb config/locales/en.yml
git commit -m "feat(conversations): add MoveToInboxService for email inbox moves"
```

---

## Task 2: Route + controller action

**Files:**
- Modify: `config/routes.rb:148-161` (the conversations `member do` block)
- Modify: `app/controllers/api/v1/accounts/conversations_controller.rb`

- [ ] **Step 1: Add the route**

In `config/routes.rb`, inside the conversations `member do` block (currently lines ~148-161, alongside `post :toggle_status`), add:

```ruby
              post :move_to_inbox
```

- [ ] **Step 2: Add the controller action**

In `app/controllers/api/v1/accounts/conversations_controller.rb`, add a public action near `toggle_status` (after the `transcript` method, before `toggle_status`):

```ruby
  def move_to_inbox
    target_inbox = Current.account.inboxes.find(params[:inbox_id])
    authorize target_inbox, :show?
    Conversations::MoveToInboxService.new(conversation: @conversation, target_inbox: target_inbox).perform
    @conversation.reload
    render 'api/v1/accounts/conversations/show', formats: [:json]
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end
```

Note: the `before_action :conversation` (line 6) already loads and authorizes `@conversation` for all actions except the excluded ones, so `move_to_inbox` gets `@conversation` and `show?` authorization for free. The `render 'show'` reuses the existing conversation show view (`app/views/api/v1/accounts/conversations/show.json.jbuilder`).

- [ ] **Step 3: Verify the route exists**

Run: `eval "$(rbenv init -)"; bundle exec rails routes -g move_to_inbox`
Expected: a line showing `POST  /api/v1/accounts/:account_id/conversations/:id/move_to_inbox`.

- [ ] **Step 4: Manual smoke test via rails console / curl (optional but recommended)**

Run: `eval "$(rbenv init -)"; bundle exec rubocop -a app/controllers/api/v1/accounts/conversations_controller.rb config/routes.rb`
Expected: no offenses.

- [ ] **Step 5: Commit**

```bash
git add config/routes.rb app/controllers/api/v1/accounts/conversations_controller.rb
git commit -m "feat(conversations): add move_to_inbox endpoint"
```

---

## Task 3: Enterprise overlay check

**Files:**
- Inspect: `enterprise/app/controllers/enterprise/api/v1/accounts/conversations_controller.rb`
- Inspect: `enterprise/app/policies/enterprise/conversation_policy.rb`

- [ ] **Step 1: Read both enterprise files**

Run: `cat enterprise/app/controllers/enterprise/api/v1/accounts/conversations_controller.rb enterprise/app/policies/enterprise/conversation_policy.rb`

- [ ] **Step 2: Decide**

The enterprise controller is prepended onto the OSS controller, so the new `move_to_inbox` action is inherited automatically — no change needed unless the enterprise policy restricts `show?` in a way that should also gate moves. The OSS `ConversationPolicy#show?` (inbox/team access) is the gate we rely on.

- If the enterprise policy does NOT override `show?` in a blocking way: **no change required.** Note this in the commit/PR.
- If it does add restrictions relevant to moving: no additional action is needed because we authorize `show?` on both the conversation and the target inbox; document that the same access rules apply.

- [ ] **Step 3: No code change expected — record finding**

No commit unless an override is required. If a change is needed, mirror it under `enterprise/` and add a spec under `spec/enterprise/`.

**Finding (inspected):** No enterprise change required.
- `Enterprise::Api::V1::Accounts::ConversationsController` is a concern that only adds methods (`inbox_assistant`, `reporting_events`, `copilot_params`) and overrides `permitted_update_params`. It does not override action dispatch, so the new `move_to_inbox` action is inherited unchanged in enterprise builds.
- `Enterprise::ConversationPolicy#show?` strengthens `show?` with custom-role permission checks (calls `super` first). Because `move_to_inbox` authorizes via `show?` on the conversation (through `before_action :conversation`) and `show?` on the target inbox, enterprise custom-role gating applies automatically. Same access rules, no override needed.

---

## Task 4: Frontend API method

**Files:**
- Modify: `app/javascript/dashboard/api/inbox/conversation.js` (after `togglePriority`, ~line 63)

- [ ] **Step 1: Add the API method**

In `app/javascript/dashboard/api/inbox/conversation.js`, add inside the `ConversationApi` class (e.g. right after `togglePriority`):

```javascript
  moveToInbox({ conversationId, inboxId }) {
    return axios.post(`${this.url}/${conversationId}/move_to_inbox`, {
      inbox_id: inboxId,
    });
  }
```

- [ ] **Step 2: Lint**

Run: `pnpm eslint app/javascript/dashboard/api/inbox/conversation.js`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add app/javascript/dashboard/api/inbox/conversation.js
git commit -m "feat(conversations): add moveToInbox API client method"
```

---

## Task 5: Frontend store action

**Files:**
- Modify: `app/javascript/dashboard/store/modules/conversations/actions.js` (after `toggleStatus`, ~line 282)

- [ ] **Step 1: Add the action**

In `app/javascript/dashboard/store/modules/conversations/actions.js`, add after the `toggleStatus` action:

```javascript
  moveConversationToInbox: async ({ commit }, { conversationId, inboxId }) => {
    const response = await ConversationApi.moveToInbox({
      conversationId,
      inboxId,
    });
    commit(types.UPDATE_CONVERSATION, response.data);
    return response.data;
  },
```

`UPDATE_CONVERSATION` (defined in `index.js:243`) merges the returned conversation (including its new `inbox_id`) into the store. Errors propagate to the caller so the component can show a toast.

- [ ] **Step 2: Lint**

Run: `pnpm eslint app/javascript/dashboard/store/modules/conversations/actions.js`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add app/javascript/dashboard/store/modules/conversations/actions.js
git commit -m "feat(conversations): add moveConversationToInbox store action"
```

---

## Task 6: Frontend i18n strings

**Files:**
- Modify: `app/javascript/dashboard/i18n/locale/en/conversation.json`

- [ ] **Step 1: Add strings**

In `app/javascript/dashboard/i18n/locale/en/conversation.json`, locate the `RESOLVE_DROPDOWN` object (it already contains `SNOOZE_UNTIL` and `MARK_PENDING`) and add a `MOVE_TO_INBOX` sibling key. Then add a top-level `MOVE_TO_INBOX` object for the modal. Concretely add:

Inside `CONVERSATION.RESOLVE_DROPDOWN`:

```json
      "MOVE_TO_INBOX": "Move to inbox"
```

And add under `CONVERSATION` (sibling of `RESOLVE_DROPDOWN`):

```json
    "MOVE_TO_INBOX": {
      "TITLE": "Move to inbox",
      "DESCRIPTION": "Select an email inbox to move this conversation to. Future replies will be sent from that inbox.",
      "SELECT_LABEL": "Inbox",
      "SELECT_PLACEHOLDER": "Select an inbox",
      "CONFIRM": "Move conversation",
      "CANCEL": "Cancel",
      "SUCCESS": "Conversation moved to %{inboxName}",
      "ERROR": "Could not move conversation. Please try again."
    }
```

Match the file's existing indentation and add a trailing comma on the line preceding any inserted key as needed so the JSON stays valid.

- [ ] **Step 2: Validate JSON**

Run: `node -e "JSON.parse(require('fs').readFileSync('app/javascript/dashboard/i18n/locale/en/conversation.json','utf8')); console.log('valid')"`
Expected: prints `valid`.

- [ ] **Step 3: Commit**

```bash
git add app/javascript/dashboard/i18n/locale/en/conversation.json
git commit -m "feat(conversations): add move to inbox i18n strings"
```

---

## Task 7: Move-to-inbox modal component

**Files:**
- Create: `app/javascript/dashboard/components-next/ConversationWorkflow/MoveToInboxModal.vue`

- [ ] **Step 1: Create the modal**

Create `app/javascript/dashboard/components-next/ConversationWorkflow/MoveToInboxModal.vue`:

```vue
<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStoreGetters } from 'dashboard/composables/store';
import { INBOX_TYPES } from 'dashboard/helper/inbox';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const props = defineProps({
  currentInboxId: {
    type: [Number, String],
    default: null,
  },
});

const emit = defineEmits(['submit']);

const { t } = useI18n();
const getters = useStoreGetters();

const dialogRef = ref(null);
const selectedInboxId = ref(null);

const emailInboxes = computed(() =>
  getters.getInboxes.value.filter(
    inbox =>
      inbox.channel_type === INBOX_TYPES.EMAIL &&
      inbox.id !== Number(props.currentInboxId)
  )
);

const isConfirmDisabled = computed(() => !selectedInboxId.value);

const open = () => {
  selectedInboxId.value = null;
  dialogRef.value?.open();
};

const close = () => {
  dialogRef.value?.close();
};

const handleConfirm = () => {
  if (!selectedInboxId.value) return;
  emit('submit', { inboxId: selectedInboxId.value });
  close();
};

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="lg"
    :title="t('CONVERSATION.MOVE_TO_INBOX.TITLE')"
    :description="t('CONVERSATION.MOVE_TO_INBOX.DESCRIPTION')"
    :confirm-button-label="t('CONVERSATION.MOVE_TO_INBOX.CONFIRM')"
    :cancel-button-label="t('CONVERSATION.MOVE_TO_INBOX.CANCEL')"
    :disable-confirm-button="isConfirmDisabled"
    @confirm="handleConfirm"
  >
    <div class="flex flex-col gap-2">
      <label class="mb-0.5 text-sm font-medium text-n-slate-12">
        {{ t('CONVERSATION.MOVE_TO_INBOX.SELECT_LABEL') }}
      </label>
      <select
        v-model="selectedInboxId"
        class="w-full reset-base text-n-slate-12 bg-n-alpha-black2 border border-n-weak rounded-lg px-3 py-2"
      >
        <option :value="null" disabled>
          {{ t('CONVERSATION.MOVE_TO_INBOX.SELECT_PLACEHOLDER') }}
        </option>
        <option
          v-for="inbox in emailInboxes"
          :key="inbox.id"
          :value="inbox.id"
        >
          {{ inbox.name }}{{ inbox.email ? ` — ${inbox.email}` : '' }}
        </option>
      </select>
    </div>
  </Dialog>
</template>
```

Note: the inbox payload exposes `email` (see `_inbox.json.jbuilder:80`), so the dropdown can show the address. `getInboxes` returns raw records with snake_case `channel_type`.

- [ ] **Step 2: Lint**

Run: `pnpm eslint app/javascript/dashboard/components-next/ConversationWorkflow/MoveToInboxModal.vue`
Expected: no errors. (If the `<select>` styling classes trip a rule, keep them as plain Tailwind utilities — do not add scoped CSS.)

- [ ] **Step 3: Commit**

```bash
git add app/javascript/dashboard/components-next/ConversationWorkflow/MoveToInboxModal.vue
git commit -m "feat(conversations): add MoveToInboxModal component"
```

---

## Task 8: Wire the Resolve dropdown to the modal

**Files:**
- Modify: `app/javascript/dashboard/components/buttons/ResolveAction.vue`

- [ ] **Step 1: Import the modal and add refs/handlers (script setup)**

In `app/javascript/dashboard/components/buttons/ResolveAction.vue`, add the import next to the existing `ConversationResolveAttributesModal` import (~line 21):

```javascript
import MoveToInboxModal from 'dashboard/components-next/ConversationWorkflow/MoveToInboxModal.vue';
```

Add a ref next to `resolveAttributesModalRef` (~line 30):

```javascript
const moveToInboxModalRef = ref(null);
```

Add a computed to detect email inboxes and the handlers (place after the `toggleStatus` function, ~line 104). The selected chat carries `inbox_id`; read the inbox's channel type from the inboxes getter:

```javascript
const isEmailInbox = computed(() => {
  const inboxId = currentChat.value?.inbox_id;
  const inbox = getters['inboxes/getInbox'].value(inboxId);
  return inbox?.channel_type === 'Channel::Email';
});

const openMoveToInboxModal = () => {
  closeDropdown();
  moveToInboxModalRef.value?.open();
};

const handleMoveToInbox = async ({ inboxId }) => {
  try {
    const data = await store.dispatch('moveConversationToInbox', {
      conversationId: currentChat.value.id,
      inboxId,
    });
    const movedInbox = getters['inboxes/getInbox'].value(inboxId);
    useAlert(
      t('CONVERSATION.MOVE_TO_INBOX.SUCCESS', {
        inboxName: movedInbox?.name || '',
      })
    );
    return data;
  } catch (error) {
    useAlert(t('CONVERSATION.MOVE_TO_INBOX.ERROR'));
    return null;
  }
};
```

Note: `getters` is already available via `const getters = useStoreGetters();` (line 24). `getters['inboxes/getInbox'].value` returns a function `(id) => inbox`.

- [ ] **Step 2: Add the dropdown item (template)**

In the `<WootDropdownMenu>` block (after the "Mark as pending" `WootDropdownItem`, ~line 252), add:

```vue
        <WootDropdownItem v-if="isEmailInbox">
          <Button
            :label="t('CONVERSATION.RESOLVE_DROPDOWN.MOVE_TO_INBOX')"
            ghost
            slate
            sm
            start
            icon="i-lucide-move-right"
            class="w-full"
            @click="() => openMoveToInboxModal()"
          />
        </WootDropdownItem>
```

- [ ] **Step 3: Mount the modal (template)**

Next to the existing `<ConversationResolveAttributesModal .../>` (~line 256), add:

```vue
    <MoveToInboxModal
      ref="moveToInboxModalRef"
      :current-inbox-id="currentChat.inbox_id"
      @submit="handleMoveToInbox"
    />
```

- [ ] **Step 4: Lint**

Run: `pnpm eslint app/javascript/dashboard/components/buttons/ResolveAction.vue`
Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add app/javascript/dashboard/components/buttons/ResolveAction.vue
git commit -m "feat(conversations): add Move to inbox action to resolve dropdown"
```

---

## Task 9: Manual end-to-end verification

**Files:** none (verification only)

- [ ] **Step 1: Seed data and start the app**

Run: `eval "$(rbenv init -)"; bundle exec rails db:seed` (if needed), then `overmind start -f Procfile.dev`.

- [ ] **Step 2: Prepare two email inboxes**

In the dashboard, ensure two email inboxes exist (e.g. Support and Event Staff). If only one exists, create a second email inbox.

- [ ] **Step 3: Move a conversation**

Open an email conversation in the Support inbox. Click the chevron next to Resolve → "Move to inbox" → pick Event Staff → confirm.

Expected:
- Success toast "Conversation moved to Event Staff".
- The conversation now appears under the Event Staff inbox; its header shows the new inbox.
- An activity line "… moved the conversation to Event Staff" appears in the timeline.

- [ ] **Step 4: Verify reply goes from the new inbox**

Reply to the moved conversation as an agent. Confirm (via mail log / `letter_opener` in dev or the SMTP debug output) the outgoing email's From / Reply-To uses the Event Staff inbox address, not Support.

- [ ] **Step 5: Confirm "Move to inbox" is hidden for non-email inboxes**

Open a non-email conversation (e.g. web widget) and verify the "Move to inbox" item does NOT appear in the Resolve dropdown.

---

## Self-Review Notes

- **Spec coverage:** Core move (inbox_id), contact_inbox repoint, message migration, activity log, and all three validation errors → Task 1 spec. Endpoint → Task 2. Enterprise → Task 3. Frontend (API/store/i18n/modal/dropdown) → Tasks 4–8. Reply-from-new-inbox (the "update receiving email" requirement) → verified in Task 9 Step 4 (no code needed; mailer resolves inbox at send time).
- **Type consistency:** `moveToInbox({ conversationId, inboxId })` (API) ↔ `moveConversationToInbox({ conversationId, inboxId })` (store) ↔ `@submit="handleMoveToInbox"` emitting `{ inboxId }` ↔ service `MoveToInboxService.new(conversation:, target_inbox:)`. Consistent throughout.
- **No placeholders:** every code/step is concrete.
