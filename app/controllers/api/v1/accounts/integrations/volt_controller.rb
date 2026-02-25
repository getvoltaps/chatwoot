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
end
