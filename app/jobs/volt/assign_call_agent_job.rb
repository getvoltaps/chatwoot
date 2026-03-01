class Volt::AssignCallAgentJob < ApplicationJob
  queue_as :default

  CALL_INBOX_ID = 6

  def perform(conversation_id)
    conversation = Conversation.find_by(id: conversation_id)
    return if conversation.blank?
    return unless conversation.inbox_id == CALL_INBOX_ID
    return if conversation.assignee_id.present?

    agent_name = (conversation.custom_attributes || {})['call_agent'].to_s.strip
    return if agent_name.blank?

    agent = find_agent(conversation, agent_name)
    return if agent.blank?

    conversation.update!(assignee_id: agent.id)
    Rails.logger.info "[Volt::AssignCallAgentJob] Assigned conversation #{conversation.display_id} to #{agent.name} (id=#{agent.id})"
  rescue StandardError => e
    Rails.logger.warn "[Volt::AssignCallAgentJob] Failed for conversation #{conversation_id}: #{e.message}"
  end

  private

  def find_agent(conversation, agent_name)
    account = conversation.account
    downcased = agent_name.downcase

    # Try exact match on name first, then display_name
    agent = account.users.find_by('LOWER(name) = ?', downcased)
    agent ||= account.users.find_by('LOWER(display_name) = ?', downcased)
    agent
  end
end
