class Volt::AiDraftJob < ApplicationJob
  queue_as :low

  def perform(conversation_id)
    Rails.logger.info "[Volt::AiDraftJob] Starting for conversation_id=#{conversation_id}"

    conversation = Conversation.find_by(id: conversation_id)
    if conversation.blank?
      Rails.logger.warn "[Volt::AiDraftJob] Conversation #{conversation_id} not found"
      return
    end

    result = Volt::AiDraftService.new(conversation).perform
    if result.blank?
      Rails.logger.warn "[Volt::AiDraftJob] No result for conversation #{conversation.display_id}"
      return
    end

    account = conversation.account
    tokens = agent_tokens(account, conversation)

    payload = {
      conversation_id: conversation.display_id,
      context: result[:context],
      draft_reply: result[:draft_reply],
      account_id: account.id
    }

    Rails.logger.info "[Volt::AiDraftJob] Broadcasting draft for conversation #{conversation.display_id} to #{tokens.size} tokens"
    ::ActionCableBroadcastJob.perform_later(tokens, 'volt.ai_draft', payload)
  end

  private

  def agent_tokens(account, conversation)
    agent_tokens = conversation.inbox.members.pluck(:pubsub_token)
    admin_tokens = account.administrators.pluck(:pubsub_token)
    (agent_tokens + admin_tokens).uniq
  end
end
