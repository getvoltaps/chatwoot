class Volt::AiDraftService
  MODEL = 'claude-haiku-4-5-20251001'.freeze
  MAX_CHARS = 100_000

  def initialize(conversation)
    @conversation = conversation
  end

  def perform
    if api_key.blank?
      Rails.logger.warn '[Volt::AiDraftService] ANTHROPIC_API_KEY is not set, skipping'
      return nil
    end

    Rails.logger.info "[Volt::AiDraftService] Generating draft for conversation #{@conversation.display_id}"

    response = HTTParty.post(
      'https://api.anthropic.com/v1/messages',
      headers: {
        'Content-Type' => 'application/json',
        'x-api-key' => api_key,
        'anthropic-version' => '2023-06-01'
      },
      body: {
        model: MODEL,
        max_tokens: 1024,
        system: system_prompt,
        messages: [{ role: 'user', content: formatted_conversation }]
      }.to_json,
      timeout: 30
    )

    unless response.success?
      Rails.logger.error "[Volt::AiDraftService] API error #{response.code}: #{response.body.to_s.truncate(500)}"
      return nil
    end

    content = response.dig('content', 0, 'text')
    result = parse_response(content)
    Rails.logger.info "[Volt::AiDraftService] Draft generated successfully for conversation #{@conversation.display_id}"
    result
  rescue StandardError => e
    Rails.logger.error "[Volt::AiDraftService] Error for conversation #{@conversation.display_id}: #{e.class} - #{e.message}"
    nil
  end

  private

  def system_prompt
    <<~PROMPT
      You are an AI assistant helping customer support agents at Volt (a festival/event rental company).
      You will receive a conversation between a customer and support agents.

      Return a JSON object with exactly two keys:
      1. "context": 2-3 short sentences summarizing what this conversation is about and any relevant history. Be concise.
      2. "draft_reply": A suggested reply the agent can send to the customer. Write naturally, be helpful, and match the conversation language. Do NOT include any email signature or sign-off.

      Output ONLY valid JSON, no markdown fences, no extra text.
    PROMPT
  end

  def formatted_conversation
    messages = @conversation.messages
                            .where(message_type: [:incoming, :outgoing])
                            .where(private: false)
                            .order(:id)

    char_count = 0
    lines = []

    messages.each do |msg|
      content = msg.content.to_s.strip
      next if content.blank?

      label = msg.incoming? ? 'Customer' : 'Agent'
      line = "#{label}: #{content}"
      break if char_count + line.length > MAX_CHARS

      lines << line
      char_count += line.length
    end

    lines.join("\n\n")
  end

  def parse_response(text)
    return nil if text.blank?

    json = JSON.parse(text)
    context = json['context'].to_s.strip
    draft = json['draft_reply'].to_s.strip
    return nil if context.blank? && draft.blank?

    { context: context, draft_reply: draft }
  rescue JSON::ParserError
    Rails.logger.warn "[Volt::AiDraftService] Failed to parse JSON response: #{text.truncate(200)}"
    nil
  end

  def api_key
    ENV.fetch('ANTHROPIC_API_KEY', nil)
  end
end
