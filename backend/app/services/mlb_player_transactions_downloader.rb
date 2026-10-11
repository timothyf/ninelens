require "json"

class MlbPlayerTransactionsDownloader
  DEFAULT_START_DATE = Date.new(1900, 1, 1)

  def self.call(player_mlb_id:, start_date: DEFAULT_START_DATE, end_date: Date.current)
    new(player_mlb_id: player_mlb_id, start_date: start_date, end_date: end_date).call
  end

  def initialize(player_mlb_id:, start_date: DEFAULT_START_DATE, end_date: Date.current)
    @player_mlb_id = Integer(player_mlb_id, exception: false)
    @start_date = parse_date(start_date)
    @end_date = parse_date(end_date)
  end

  def call
    return failure("Player MLB id must be a positive integer") unless player_mlb_id&.positive?
    return failure("Start date and end date are required") if start_date.nil? || end_date.nil?
    return failure("End date must be on or after start date") if end_date < start_date

    source_url = build_url
    payload = fetch_json(source_url)
    return failure("MLB transactions response must be a JSON object") unless payload.is_a?(Hash)
    return failure("MLB transactions response must include a transactions array") unless payload["transactions"].is_a?(Array)

    hydrated_payload = fetch_json(build_person_url)
    hydrated_transactions = extract_transactions(hydrated_payload)
    payload["transactions"] = merge_transactions(payload["transactions"], hydrated_transactions)

    success(
      "Downloaded #{payload['transactions'].length} MLB player transactions",
      payload: payload,
      transaction_count: payload["transactions"].length,
      source_url: source_url,
      fetched_at: Time.current.utc.iso8601
    )
  rescue JSON::ParserError => error
    failure("Failed to parse MLB transactions response: #{error.message}")
  rescue StandardError => error
    failure("Failed to download MLB player transactions: #{error.message}")
  end

  private

  attr_reader :player_mlb_id, :start_date, :end_date

  def build_url
    query = {
      playerId: player_mlb_id,
      startDate: start_date.strftime("%m/%d/%Y"),
      endDate: end_date.strftime("%m/%d/%Y")
    }.to_query
    "#{service_config.fetch(:base_url)}/api/v1/transactions?#{query}"
  end

  def build_person_url
    "#{service_config.fetch(:base_url)}/api/v1/people/#{player_mlb_id}?hydrate=transactions"
  end

  def extract_transactions(payload)
    return [] unless payload.is_a?(Hash)

    direct = payload["transactions"]
    return direct if direct.is_a?(Array)

    person = Array(payload["people"]).first
    person.is_a?(Hash) && person["transactions"].is_a?(Array) ? person["transactions"] : []
  end

  def merge_transactions(primary, hydrated)
    (primary + hydrated).uniq { |transaction| transaction["id"] || transaction }
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

  def parse_date(value)
    return value if value.is_a?(Date)

    Date.iso8601(value.to_s)
  rescue Date::Error
    nil
  end

  def success(message, data = {})
    { success: true, message: message, data: data }
  end

  def failure(message)
    { success: false, message: message, data: {} }
  end
end
