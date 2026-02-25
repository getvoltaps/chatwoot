class Api::V1::Accounts::Integrations::VoltController < Api::V1::Accounts::BaseController
  VOLT_API_KEY = 'sV0NLsVU491ur69tv6UUslrKppPWUrl8kU7Sb7XM6MSD7MiC'.freeze

  def search
    query = params[:q]
    return render json: { users: [] }, status: :ok if query.blank?

    response = HTTParty.get(
      'https://api.getvolt.dk/v2/service/search',
      query: { q: query },
      headers: { 'Content-Type' => 'application/json' }
    )

    if response.success?
      render json: response.parsed_response, status: :ok
    else
      render json: { error: 'Volt API error' }, status: :unprocessable_entity
    end
  end

  def editions
    response = HTTParty.get(
      'https://api.getvolt.dk/editions',
      headers: { 'Content-Type' => 'application/json', 'x-api-key' => VOLT_API_KEY }
    )

    if response.success?
      render json: response.parsed_response, status: :ok
    else
      render json: { error: 'Volt API error' }, status: :unprocessable_entity
    end
  end

  def ai_draft
    conversation = Current.account.conversations.find_by!(display_id: params[:conversation_id])
    authorize conversation, :show?
    Volt::AiDraftJob.perform_later(conversation.id, params[:agent_context].presence)
    render json: { message: 'AI draft generation started' }, status: :ok
  end

  def ai_stats
    account = Current.account
    indexed_count = Volt::ConversationSummary.where(account_id: account.id).count
    resolved_count = account.conversations.where(status: :resolved)
                            .joins(:messages)
                            .where(messages: { message_type: [:incoming, :outgoing] })
                            .distinct.count
    latest_indexed = Volt::ConversationSummary.where(account_id: account.id).order(created_at: :desc).first

    render json: {
      indexed_conversations: indexed_count,
      total_resolved_conversations: resolved_count,
      coverage_percentage: resolved_count.positive? ? ((indexed_count.to_f / resolved_count) * 100).round(1) : 0,
      last_indexed_at: latest_indexed&.created_at,
      api_key_configured: ENV.fetch('ANTHROPIC_API_KEY', nil).present?
    }, status: :ok
  end

  def ai_backfill
    account = Current.account
    existing_ids = Volt::ConversationSummary.where(account_id: account.id).pluck(:conversation_id)

    scope = account.conversations.where(status: :resolved)
                   .joins(:messages)
                   .where(messages: { message_type: [:incoming, :outgoing] })
                   .distinct
    scope = scope.where.not(id: existing_ids) if existing_ids.any?

    count = scope.count
    scope.find_each(batch_size: 100) do |conversation|
      Volt::IndexConversationJob.perform_later(conversation.id)
    end

    render json: { message: "Enqueued #{count} conversations for indexing" }, status: :ok
  end

  def edition_report
    account = Current.account
    scope = account.conversations
    scope = scope.where('conversations.created_at >= ?', Time.zone.parse(params[:since])) if params[:since].present?
    scope = scope.where('conversations.created_at <= ?', Time.zone.parse(params[:until])) if params[:until].present?

    edition_counts = scope
                     .where("custom_attributes->>'volt_edition' IS NOT NULL")
                     .where("custom_attributes->>'volt_edition' != ''")
                     .group("custom_attributes->>'volt_edition'")
                     .order(Arel.sql('count(*) DESC'))
                     .count

    editions = edition_counts.map { |name, count| { name: name, count: count } }
    top_5 = editions.first(5)

    # Generate AI summaries for top 5 editions on demand
    summaries = generate_edition_summaries(account, top_5.map { |e| e[:name] }, scope)

    render json: {
      editions: editions,
      total_tickets: scope.count,
      total_with_edition: edition_counts.values.sum,
      summaries: summaries
    }, status: :ok
  end

  private

  def generate_edition_summaries(account, edition_names, scope)
    api_key = ENV.fetch('ANTHROPIC_API_KEY', nil)
    return {} if api_key.blank? || edition_names.empty?

    summaries = {}
    edition_names.each do |edition_name|
      conversation_ids = scope
                         .where("custom_attributes->>'volt_edition' = ?", edition_name)
                         .order(created_at: :desc)
                         .limit(20)
                         .pluck(:id)

      indexed = Volt::ConversationSummary
                .where(account_id: account.id, conversation_id: conversation_ids)
                .limit(10)
                .pluck(:content)

      next if indexed.empty?

      prompt_text = indexed.map.with_index(1) { |c, i| "--- Ticket #{i} ---\n#{c}" }.join("\n\n")

      response = HTTParty.post(
        'https://api.anthropic.com/v1/messages',
        headers: {
          'Content-Type' => 'application/json',
          'x-api-key' => api_key,
          'anthropic-version' => '2023-06-01'
        },
        body: {
          model: 'claude-haiku-4-5-20251001',
          max_tokens: 256,
          system: 'You summarize customer support ticket themes. Return ONLY a 2-3 sentence summary of the most common issues and themes. No JSON, no formatting, just plain text.',
          messages: [{ role: 'user', content: "Here are recent tickets for the edition \"#{edition_name}\":\n\n#{prompt_text}\n\nSummarize the most common themes and issues in 2-3 sentences." }]
        }.to_json,
        timeout: 15
      )

      if response.success?
        summaries[edition_name] = response.dig('content', 0, 'text').to_s.strip
      end
    rescue StandardError => e
      Rails.logger.warn "[VoltController] Edition summary failed for #{edition_name}: #{e.message}"
    end

    summaries
  end
end
