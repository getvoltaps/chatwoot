class Volt::AssignCallEditionJob < ApplicationJob
  queue_as :default

  CALL_INBOX_ID = 6
  VOLT_API_KEY = Api::V1::Accounts::Integrations::VoltController::VOLT_API_KEY

  def perform(conversation_id)
    conversation = Conversation.find_by(id: conversation_id)
    return if conversation.blank?
    return unless conversation.inbox_id == CALL_INBOX_ID

    attrs = conversation.custom_attributes || {}
    return if attrs['volt_edition'].present?

    call_queue = attrs['call_queue'].to_s.strip
    Rails.logger.info "[Volt::AssignCallEditionJob] Conv #{conversation.display_id} call_queue=#{call_queue.inspect}"
    return if call_queue.blank?

    # Extract UUID from call_queue — handles formats like:
    #   "e2d840bb-ea7d-485a-b58e-f1cdd5664dc5"
    #   "e2d840bb-ea7d-485a-b58e-f1cdd5664dc5 → support (fallback)"
    #   "e2d840bb-ea7d-485a-b58e-f1cdd5664dc5 -> support (fallback)"
    uuid_match = call_queue.match(/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/i)
    unless uuid_match
      Rails.logger.info "[Volt::AssignCallEditionJob] No UUID found in call_queue=#{call_queue.inspect} for conv #{conversation.display_id}"
      return
    end

    edition_id = uuid_match[1]
    edition_name = fetch_edition_name(edition_id)
    if edition_name.blank?
      Rails.logger.info "[Volt::AssignCallEditionJob] No edition found for UUID #{edition_id} (conv #{conversation.display_id})"
      return
    end

    conversation.update!(custom_attributes: attrs.merge('volt_edition' => edition_name))
    Rails.logger.info "[Volt::AssignCallEditionJob] Set volt_edition='#{edition_name}' for conversation #{conversation.display_id}"
  rescue StandardError => e
    Rails.logger.warn "[Volt::AssignCallEditionJob] Failed for conversation #{conversation_id}: #{e.message}"
  end

  private

  def fetch_edition_name(edition_id)
    response = HTTParty.get(
      "https://api.getvolt.dk/twilio/editions/#{edition_id}",
      headers: { 'Content-Type' => 'application/json', 'x-api-key' => VOLT_API_KEY },
      timeout: 10
    )
    return nil unless response.success?

    response.parsed_response&.dig('name')
  rescue StandardError => e
    Rails.logger.warn "[Volt::AssignCallEditionJob] Edition lookup failed for #{edition_id}: #{e.message}"
    nil
  end
end
