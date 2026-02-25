class Volt::AiDraftService
  MODEL = 'claude-haiku-4-5-20251001'.freeze
  MAX_CHARS = 100_000
  MAX_SIMILAR = 3

  def initialize(conversation, agent_context: nil)
    @conversation = conversation
    @agent_context = agent_context
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
        messages: [{ role: 'user', content: user_message }]
      }.to_json,
      timeout: 30
    )

    unless response.success?
      Rails.logger.error "[Volt::AiDraftService] API error #{response.code}: #{response.body.to_s.truncate(500)}"
      return nil
    end

    content = response.dig('content', 0, 'text')
    result = parse_response(content)
    if result
      Rails.logger.info "[Volt::AiDraftService] Draft generated successfully for conversation #{@conversation.display_id}"
    end
    result
  rescue StandardError => e
    Rails.logger.error "[Volt::AiDraftService] Error for conversation #{@conversation.display_id}: #{e.class} - #{e.message}"
    nil
  end

  private

  def system_prompt
    editions = edition_names
    edition_list = editions.any? ? editions.join(', ') : 'No editions available'

    base = <<~PROMPT
      You are an AI assistant helping customer support agents at Volt (a festival/event rental company).
      You will receive a conversation between a customer and support agents.

      Return a JSON object with these keys:
      1. "context": 2-3 short sentences summarizing what this conversation is about and any relevant history. Be concise.
      2. "draft_reply": A suggested reply the agent can send to the customer. Write naturally, be helpful, and match the conversation language. Do NOT include any email signature or sign-off.
      3. "edition": The best matching edition/event name from this list: #{edition_list}. Pick the single best match based on conversation context. If unclear, use null.
      4. "product": One of: Volt Charging, Brick Charging, Locker, Cool Locker, Soundboks, Soundlock, Other products. Pick the best match. If unclear, use "Other products".
      5. "subject": One of: Order confirmation, Deposits, Changes to order, Cancellation, Problems on-site, Complaints, Technical issues, Sales lead, General / Other. Pick the best match. If unclear, use "General / Other".

      Output ONLY valid JSON, no markdown fences, no extra text.
    PROMPT

    examples = similar_conversations_prompt
    return base if examples.blank?

    base + examples
  end

  def similar_conversations_prompt
    similar = find_similar_conversations
    return nil if similar.empty?

    sections = similar.map.with_index(1) do |record, i|
      "--- Example #{i} ---\n#{record.content}"
    end

    <<~PROMPT

      Here are #{similar.size} similar past conversations that were successfully resolved. Use them as reference for tone, style, and the kind of answers that work:

      #{sections.join("\n\n")}

      Use these examples to inform your draft reply, but tailor it to the current conversation. Do not copy responses verbatim.
    PROMPT
  end

  def find_similar_conversations
    Volt::ConversationSummary.search_similar(
      formatted_conversation,
      account_id: @conversation.account_id,
      limit: MAX_SIMILAR,
      exclude_conversation_id: @conversation.id
    )
  rescue StandardError => e
    Rails.logger.warn "[Volt::AiDraftService] Similar conversation lookup failed: #{e.message}"
    []
  end

  def user_message
    msg = formatted_conversation
    return msg if @agent_context.blank?

    "#{msg}\n\n--- Agent note ---\nThe agent has provided this additional context for the draft reply: #{@agent_context}"
  end

  def formatted_conversation
    @formatted_conversation ||= begin
      messages = @conversation.messages
                              .where(message_type: [:incoming, :outgoing])
                              .where(private: false)
                              .order(:id)

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

      lines.join("\n\n")
    end
  end

  def parse_response(text)
    return nil if text.blank?

    # Strip markdown code fences if present (e.g. ```json ... ```)
    cleaned = text.strip.gsub(/\A```\w*\n?/, '').gsub(/\n?```\z/, '').strip
    json = JSON.parse(cleaned)
    context = json['context'].to_s.strip
    draft = json['draft_reply'].to_s.strip
    return nil if context.blank? && draft.blank?

    {
      context: context,
      draft_reply: draft,
      edition: json['edition'].presence,
      product: json['product'].presence,
      subject: json['subject'].presence
    }
  rescue JSON::ParserError
    Rails.logger.warn "[Volt::AiDraftService] Failed to parse JSON response: #{text.truncate(200)}"
    nil
  end

  def edition_names
    @edition_names ||= begin
      response = HTTParty.get(
        'https://api.getvolt.dk/editions',
        headers: { 'Content-Type' => 'application/json', 'x-api-key' => Api::V1::Accounts::Integrations::VoltController::VOLT_API_KEY },
        timeout: 10
      )
      return [] unless response.success?

      editions = response.parsed_response
      editions = editions['editions'] if editions.is_a?(Hash) && editions.key?('editions')
      return [] unless editions.is_a?(Array)

      editions.filter_map { |e| e['name'].presence || e['title'].presence }
    rescue StandardError => e
      Rails.logger.warn "[Volt::AiDraftService] Failed to fetch editions: #{e.message}"
      []
    end
  end

  def api_key
    ENV.fetch('ANTHROPIC_API_KEY', nil)
  end
end
