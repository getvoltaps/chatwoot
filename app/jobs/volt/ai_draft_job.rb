class Volt::AiDraftJob < ApplicationJob
  queue_as :low

  def perform(conversation_id, agent_context = nil)
    Rails.logger.info "[Volt::AiDraftJob] Starting for conversation_id=#{conversation_id} (agent_context: #{agent_context.present?})"

    conversation = Conversation.find_by(id: conversation_id)
    if conversation.blank?
      Rails.logger.warn "[Volt::AiDraftJob] Conversation #{conversation_id} not found"
      return
    end

    result = Volt::AiDraftService.new(conversation, agent_context: agent_context).perform
    if result.blank?
      Rails.logger.warn "[Volt::AiDraftJob] No result for conversation #{conversation.display_id}"
      return
    end

    auto_filled = autofill_custom_attributes(conversation, result)

    account = conversation.account
    tokens = agent_tokens(account, conversation)

    payload = {
      conversation_id: conversation.display_id,
      context: result[:context],
      draft_reply: result[:draft_reply],
      account_id: account.id,
      auto_filled: auto_filled
    }

    Rails.logger.info "[Volt::AiDraftJob] Broadcasting draft for conversation #{conversation.display_id} to #{tokens.size} tokens (auto_filled: #{auto_filled.keys})"
    ::ActionCableBroadcastJob.perform_later(tokens, 'volt.ai_draft', payload)
  end

  private

  FIELD_MAPPING = {
    'volt_edition' => :edition,
    'volt_product' => :product,
    'volt_subject' => :subject
  }.freeze

  def autofill_custom_attributes(conversation, result)
    attrs = conversation.custom_attributes || {}
    filled = {}

    FIELD_MAPPING.each do |attr_key, result_key|
      next if attrs[attr_key].present?
      next if result[result_key].blank?

      filled[attr_key] = result[result_key]
    end

    if filled.any?
      conversation.update!(custom_attributes: attrs.merge(filled))
      Rails.logger.info "[Volt::AiDraftJob] Auto-filled custom attributes for conversation #{conversation.display_id}: #{filled}"
    end

    filled
  end

  def agent_tokens(account, conversation)
    agent_tokens = conversation.inbox.members.pluck(:pubsub_token)
    admin_tokens = account.administrators.pluck(:pubsub_token)
    (agent_tokens + admin_tokens).uniq
  end
end
