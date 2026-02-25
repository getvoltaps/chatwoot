class Volt::AiDraftJob < ApplicationJob
  queue_as :low

  def perform(conversation_id)
    conversation = Conversation.find_by(id: conversation_id)
    return if conversation.blank?

    result = Volt::AiDraftService.new(conversation).perform
    return if result.blank?

    account = conversation.account
    tokens = agent_tokens(account, conversation)

    payload = {
      conversation_id: conversation.display_id,
      context: result[:context],
      draft_reply: result[:draft_reply],
      account_id: account.id
    }

    ::ActionCableBroadcastJob.perform_later(tokens, 'volt.ai_draft', payload)
  end

  private

  def agent_tokens(account, conversation)
    agent_tokens = conversation.inbox.members.pluck(:pubsub_token)
    admin_tokens = account.administrators.pluck(:pubsub_token)
    (agent_tokens + admin_tokens).uniq
  end
end
