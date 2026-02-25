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
    Volt::AiDraftJob.perform_later(conversation.id)
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
end
