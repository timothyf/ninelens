require "json"

class MlbTradeDetailsDownloader
  def self.call(mlb_transaction_id:)
    new(mlb_transaction_id: mlb_transaction_id).call
  end

  def initialize(mlb_transaction_id:)
    @mlb_transaction_id = Integer(mlb_transaction_id, exception: false)
  end

  def call
    return failure("MLB transaction id must be a positive integer") unless mlb_transaction_id&.positive?

    source_url = build_url
    payload = fetch_json(source_url)
    return failure("MLB trade response must be a JSON object") unless payload.is_a?(Hash)
    return failure("MLB trade response must include a transactions array") unless payload["transactions"].is_a?(Array)

    transactions = payload["transactions"].select do |transaction|
      transaction["id"].to_i == mlb_transaction_id && transaction["typeCode"].to_s.upcase == "TR"
    end
    return failure("MLB transaction #{mlb_transaction_id} did not return trade participants") if transactions.empty?

    payload["transactions"] = transactions
    success(
      "Downloaded #{transactions.length} participants for MLB trade #{mlb_transaction_id}",
      payload: payload,
      participant_count: transactions.length,
      source_url: source_url,
      fetched_at: Time.current.utc.iso8601
    )
  rescue JSON::ParserError => error
    failure("Failed to parse MLB trade response: #{error.message}")
  rescue StandardError => error
    failure("Failed to download MLB trade details: #{error.message}")
  end

  private

  attr_reader :mlb_transaction_id

  def build_url
    query = { transactionIds: mlb_transaction_id }.to_query
    "#{service_config.fetch(:base_url)}/api/v1/transactions?#{query}"
  end

  def fetch_json(url)
    MlbStatsApiClient.get_json(
      url,
      user_agent: service_config.fetch(:user_agents).fetch(:transactions)
    )
  end

  def service_config
    @service_config ||= NineLensConfig.fetch(:external_services, :mlb_stats_api)
  end

  def success(message, data = {})
    { success: true, message: message, data: data }
  end

  def failure(message)
    { success: false, message: message, data: {} }
  end
end
