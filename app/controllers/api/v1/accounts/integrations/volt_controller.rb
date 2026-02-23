class Api::V1::Accounts::Integrations::VoltController < Api::V1::Accounts::BaseController
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
end
