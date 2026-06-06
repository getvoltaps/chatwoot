# Move Conversation Between Email Inboxes — Design

**Date:** 2026-06-06
**Status:** Approved design, ready for implementation planning

## Summary

Add the ability to move an open conversation from one email inbox to another
(e.g. from `support@getvolt.dk` to `eventstaff@getvolt.dk`). After the move, the
conversation lives in the target inbox and future agent replies are sent **from**
the target inbox's address using the target inbox's SMTP. The customer's replies
then naturally land in the new inbox, so the "receiving email" follows the move
automatically.

Scope is **email inboxes only** (`Channel::Email`). Other channel types are out
of scope.

## Why this is feasible without touching the mailer

The `ConversationReplyMailer` resolves `@inbox = @conversation.inbox` and
`@channel = @inbox.channel` **at send time**:

- From / Reply-To addresses are derived from `conversation.inbox.channel.email`
  (via `Email::FromBuilder` / `Email::ReplyToBuilder`, or the legacy paths which
  fall back to the conversation UUID reply address).
- SMTP delivery settings are chosen from `conversation.inbox.channel` SMTP fields
  (see `conversation_reply_mailer_helper.rb`).

Therefore, once we change `conversation.inbox_id` correctly, the next agent reply
goes out from the new inbox with **no mailer changes**.

Threading also survives the move: inbound routing's primary strategies
(`ReceiverUuidStrategy`, `InReplyToStrategy`) match on `conversation.uuid`, which
never changes, independent of inbox. `conversation.uuid` is permanent.

## Behavior decisions

- **Move semantics:** Move everything in place — update `inbox_id` on the
  conversation and on its existing messages; reuse/create one `contact_inbox` in
  the target inbox; keep the same conversation (and same `uuid`).
- **Receiving email:** Handled implicitly — outgoing mail follows
  `conversation.inbox`, so future replies route to the new inbox.

## Architecture

### Backend

**New service: `Conversations::MoveToInboxService`**

Responsibilities (single transaction):

1. **Validate**
   - Target inbox exists and belongs to the conversation's account.
   - Target inbox is an email inbox (`Channel::Email`).
   - Target inbox differs from the current inbox.
   - Contact has an email (needed for the email `contact_inbox.source_id`).
2. **Resolve target `ContactInbox`**
   - Find existing `ContactInbox` for `(contact, target_inbox)`.
   - Otherwise create one with `source_id = contact.email`.
3. **Update in place (transaction)**
   - `conversation.inbox_id = target_inbox.id`
   - `conversation.contact_inbox_id = target_contact_inbox.id`
   - `conversation.messages.update_all(inbox_id: target_inbox.id)`
4. **Audit** — record an activity message in the conversation timeline
   (e.g. "Conversation moved from Support to Event Staff").

**Controller action: `move_to_inbox`**

- Route: `POST /api/v1/accounts/:account_id/conversations/:id/move_to_inbox`,
  added as a member action next to existing actions (`toggle_status`, etc.) in
  `config/routes.rb`.
- Handled by a new `move_to_inbox` action in
  `app/controllers/api/v1/accounts/conversations_controller.rb`.
- Body: `{ inbox_id }`.
- Calls `Conversations::MoveToInboxService`.
- Responds with the updated conversation using the existing conversation
  serializer, so the frontend store can update in place.

**Authorization**

- Reuse the existing conversation policy (user must already have access to the
  conversation).
- Additionally validate the target inbox belongs to the account and is accessible
  to the agent (scoped through the user's accessible inboxes). Otherwise reject.

**Error cases (minimal, happy-path-first)**

- Target inbox not found / not in account → 404/422.
- Target inbox is not an email inbox → 422 ("Only email inboxes are supported").
- Target inbox == current inbox → 422 (no-op).
- Contact has no email → 422 with a clear message.

### Frontend

**Entry point — Resolve dropdown**

In `app/javascript/dashboard/components/buttons/ResolveAction.vue`, alongside
*Snooze* and *Mark as pending* (lines ~229–252), add a **"Move to inbox"** item.
Shown only when the conversation's current inbox is an email inbox
(`channel_type === 'Channel::Email'`). Clicking it opens the modal.

**New modal — `MoveToInboxModal.vue`** (under `components-next/`, using the
`Dialog` + `ref` `open()/close()` pattern from
`ConversationResolveAttributesModal.vue`):

- Single dropdown listing **email inboxes only**
  (`channel_type === INBOX_TYPES.EMAIL`), excluding the current inbox.
- Each option shows inbox name and email address
  (e.g. "Event Staff — eventstaff@getvolt.dk").
- Confirm button ("Move conversation"), disabled until an inbox is selected.

**Wiring**

- New API method `moveToInbox({ conversationId, inboxId })` in
  `app/javascript/dashboard/api/inbox/conversation.js` →
  `POST /conversations/:id/move_to_inbox`.
- New store action `moveConversationToInbox` in
  `app/javascript/dashboard/store/modules/conversations/actions.js`, following the
  `toggleStatus` pattern (dispatch → update conversation in store →
  success/error toast).
- On success: close modal, show a toast ("Moved to Event Staff").

## Enterprise considerations

Per project conventions, during implementation confirm whether `enterprise/`
overrides the conversations controller or the conversation policy, and mirror
behavior there if needed. The core service stays in OSS. Keep request/response
contracts identical across OSS and Enterprise.

## i18n

Add new strings to `config/locales/en.yml` (backend) and the dashboard
`en.json` (frontend) only — other languages handled by the community.

New frontend strings (under conversation resolve/move namespace):

- "Move to inbox"
- Modal title, inbox-select label, confirm button, success toast, error messages.

## Out of scope

- Moving between non-email channel types.
- Bulk move of multiple conversations.
- Rewriting historical message addresses beyond `inbox_id`.
- Notifying the customer of an address change (handled implicitly by reply From).
