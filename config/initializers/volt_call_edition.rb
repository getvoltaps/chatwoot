Rails.application.config.after_initialize do
  Conversation.class_eval do
    after_commit :volt_assign_call_edition, :volt_assign_call_agent, on: %i[create update]

    private

    def volt_assign_call_edition
      return unless inbox_id == Volt::AssignCallEditionJob::CALL_INBOX_ID

      attrs = custom_attributes || {}
      return if attrs['volt_edition'].present?
      return if attrs['call_edition'].blank?

      Volt::AssignCallEditionJob.perform_later(id)
    end

    def volt_assign_call_agent
      return unless inbox_id == Volt::AssignCallAgentJob::CALL_INBOX_ID
      return if assignee_id.present?

      attrs = custom_attributes || {}
      return if attrs['call_agent'].blank?

      Volt::AssignCallAgentJob.perform_later(id)
    end
  end
end
