Rails.application.config.after_initialize do
  Conversation.class_eval do
    after_commit :volt_assign_call_edition, on: %i[create update]

    private

    def volt_assign_call_edition
      return unless inbox_id == Volt::AssignCallEditionJob::CALL_INBOX_ID

      attrs = custom_attributes || {}
      return if attrs['volt_edition'].present?

      if attrs['call_queue'].blank?
        Rails.logger.debug "[volt_call_edition] Conv #{display_id} in inbox 6 but no call_queue yet"
        return
      end

      Rails.logger.info "[volt_call_edition] Enqueuing AssignCallEditionJob for conv #{display_id} (call_queue=#{attrs['call_queue'].inspect})"
      Volt::AssignCallEditionJob.perform_later(id)
    end
  end
end
