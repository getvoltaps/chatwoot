Rails.application.config.after_initialize do
  Conversation.after_commit :volt_assign_call_edition, on: %i[create update]
end

Conversation.class_eval do
  private

  def volt_assign_call_edition
    return unless inbox_id == Volt::AssignCallEditionJob::CALL_INBOX_ID

    attrs = custom_attributes || {}
    return if attrs['volt_edition'].present?
    return if attrs['call_queue'].blank?

    Volt::AssignCallEditionJob.perform_later(id)
  end
end
