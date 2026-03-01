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
    return if call_queue.blank?

    # Extract edition UUID from call_queue (e.g. "e2d840bb-ea7d-... → support (fallback)")
    edition_id = call_queue.split('→').first.strip
    return unless edition_id.match?(/\A[0-9a-f-]{36}\z/)

    edition_name = fetch_edition_name(edition_id)
    return if edition_name.blank?

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
