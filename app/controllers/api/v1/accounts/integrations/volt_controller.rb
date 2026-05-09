class Api::V1::Accounts::Integrations::VoltController < Api::V1::Accounts::BaseController
  VOLT_API_KEY = 'sV0NLsVU491ur69tv6UUslrKppPWUrl8kU7Sb7XM6MSD7MiC'.freeze

  def search
    query = params[:q]
    return render json: { users: [] }, status: :ok if query.blank?

    response = HTTParty.get(
      'https://api.getvolt.dk/v2/service/search',
      query: { q: query },
      headers: { 'Content-Type' => 'application/json', 'x-api-key' => VOLT_API_KEY }
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

  # --- Volunteer member profile (proxy to volt-member-sidecar) ---

  def member_profile
    email = params[:email]
    return render json: { error: 'email param required' }, status: :bad_request if email.blank?

    sidecar_url = ENV.fetch('VOLT_SIDECAR_URL', 'http://localhost:3100')
    response = HTTParty.get("#{sidecar_url}/member", query: { email: email }, timeout: 30)

    if response.success?
      render json: response.parsed_response, status: :ok
    elsif response.code == 404
      render json: { error: 'Member not found' }, status: :not_found
    else
      render json: { error: 'Sidecar error' }, status: :bad_gateway
    end
  rescue StandardError => e
    Rails.logger.error "[VoltController] member_profile failed: #{e.message}"
    render json: { error: e.message }, status: :bad_gateway
  end

  # --- Twilio Queue Management (proxy to api.getvolt.dk) ---

  def twilio_editions
    proxy_get('/twilio/editions')
  end

  def twilio_edition
    proxy_get("/twilio/editions/#{params[:edition_id]}")
  end

  def twilio_add_edition_agent
    proxy_post("/twilio/editions/#{params[:edition_id]}/agents", twilio_agent_params)
  end

  def twilio_remove_edition_agent
    proxy_delete("/twilio/editions/#{params[:edition_id]}/agents/#{params[:assignment_id]}")
  end

  def twilio_queues
    proxy_get('/twilio/queues')
  end

  # Agent list (InternalUsers with phone numbers)
  def twilio_agents
    proxy_get('/twilio/agents')
  end

  def twilio_agent
    proxy_get("/twilio/agents/#{encoded_agent_id}")
  end

  # Agent assignment CRUD
  def twilio_agent_assignments
    proxy_get("/twilio/agents/#{encoded_agent_id}/assignments")
  end

  def twilio_add_assignment
    proxy_post("/twilio/agents/#{encoded_agent_id}/assignments", twilio_assignment_params)
  end

  def twilio_update_assignment
    proxy_put("/twilio/agents/#{encoded_agent_id}/assignments/#{params[:assignment_id]}", twilio_assignment_params)
  end

  def twilio_delete_assignment
    proxy_delete("/twilio/agents/#{encoded_agent_id}/assignments/#{params[:assignment_id]}")
  end

  # --- Twilio Opening Hours (proxy to api.getvolt.dk) ---

  def twilio_opening_hours
    proxy_get('/twilio/opening-hours')
  end

  def twilio_queue_hours
    proxy_get("/twilio/opening-hours/queue/#{params[:queue_name]}")
  end

  def twilio_update_queue_hours
    proxy_put("/twilio/opening-hours/queue/#{params[:queue_name]}", opening_hours_params)
  end

  def twilio_edition_hours
    proxy_get("/twilio/opening-hours/edition/#{params[:edition_id]}")
  end

  def twilio_update_edition_hours
    proxy_put("/twilio/opening-hours/edition/#{params[:edition_id]}", opening_hours_params)
  end

  def twilio_delete_edition_hours
    proxy_delete("/twilio/opening-hours/edition/#{params[:edition_id]}")
  end

  private

  def encoded_agent_id
    ERB::Util.url_encode(params[:agent_id])
  end

  def twilio_agent_params
    params.permit(:internal_user_id, :priority, :is_active).to_h.compact
  end

  def twilio_assignment_params
    params.permit(:queue_name, :edition_id, :priority, :is_active).to_h.compact
  end

  def opening_hours_params
    { opening_hours: params.require(:opening_hours).permit!.to_h }
  end

  def volt_api_headers
    { 'Content-Type' => 'application/json', 'x-api-key' => VOLT_API_KEY }
  end

  def proxy_get(path, query = {})
    response = HTTParty.get("https://api.getvolt.dk#{path}", headers: volt_api_headers, query: query, timeout: 10)
    proxy_render(response)
  rescue StandardError => e
    Rails.logger.error "[VoltController] proxy_get #{path} failed: #{e.message}"
    render json: { error: e.message }, status: :bad_gateway
  end

  def proxy_post(path, body = {})
    response = HTTParty.post("https://api.getvolt.dk#{path}", headers: volt_api_headers, body: body.to_json, timeout: 10)
    proxy_render(response)
  rescue StandardError => e
    Rails.logger.error "[VoltController] proxy_post #{path} failed: #{e.message}"
    render json: { error: e.message }, status: :bad_gateway
  end

  def proxy_put(path, body = {})
    response = HTTParty.put("https://api.getvolt.dk#{path}", headers: volt_api_headers, body: body.to_json, timeout: 10)
    proxy_render(response)
  rescue StandardError => e
    Rails.logger.error "[VoltController] proxy_put #{path} failed: #{e.message}"
    render json: { error: e.message }, status: :bad_gateway
  end

  def proxy_delete(path)
    response = HTTParty.delete("https://api.getvolt.dk#{path}", headers: volt_api_headers, timeout: 10)
    head response.code
  rescue StandardError => e
    Rails.logger.error "[VoltController] proxy_delete #{path} failed: #{e.message}"
    render json: { error: e.message }, status: :bad_gateway
  end

  def proxy_render(response)
    body = response.parsed_response
    status = response.code

    if body.nil?
      render json: { error: "Upstream returned #{status}", body: response.body.to_s.truncate(500) }, status: status
    else
      render json: body, status: status
    end
  end

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
