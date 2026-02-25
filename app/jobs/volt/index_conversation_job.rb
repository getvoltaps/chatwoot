class Volt::IndexConversationJob < ApplicationJob
  queue_as :low

  MAX_CHARS = 8000

  def perform(conversation_id)
    conversation = Conversation.find_by(id: conversation_id)
    return if conversation.blank?

    content = build_content(conversation)
    if content.blank?
      Rails.logger.info "[Volt::IndexConversationJob] No content for conversation #{conversation.display_id}, skipping"
      return
    end

    record = Volt::ConversationSummary.find_or_initialize_by(conversation_id: conversation.id)
    record.update!(
      account_id: conversation.account_id,
      content: content
    )

    Rails.logger.info "[Volt::IndexConversationJob] Indexed conversation #{conversation.display_id}"
  end

  private

  def build_content(conversation)
    messages = conversation.messages
                           .where(message_type: [:incoming, :outgoing])
                           .where(private: false)
                           .order(:created_at)

    char_count = 0
    lines = []

    messages.each do |msg|
      text = msg.content.to_s.strip
      next if text.blank?

      label = msg.incoming? ? 'Customer' : 'Agent'
      line = "#{label}: #{text}"
      break if char_count + line.length > MAX_CHARS

      lines << line
      char_count += line.length
    end

    lines.join("\n")
  end
end
