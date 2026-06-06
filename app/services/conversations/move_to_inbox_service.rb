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
    raise ArgumentError, 'Target inbox not in account' if target_inbox.account_id != conversation.account_id
    raise ArgumentError, 'Already in this inbox' if target_inbox.id == conversation.inbox_id
    raise ArgumentError, 'Only email inboxes are supported' unless target_inbox.channel_type == 'Channel::Email'
    raise ArgumentError, 'Contact has no email' if conversation.contact.email.blank?
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
      user_name: Current.user&.name || I18n.t('automation.system_name'),
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
