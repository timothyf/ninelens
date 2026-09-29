require "json"
require "net/http"

class MlbScheduleDownloader
  # MLB schedule game types: regular season plus Wild Card, Division Series,
  # League Championship Series, and World Series postseason games.
  DEFAULT_GAME_TYPES = "R,W,D,L,F"

  attr_reader :start_date, :end_date, :game_types, :sport_id

  def self.call(start_date:, end_date:, game_types: DEFAULT_GAME_TYPES, sport_id: 1)
    new(start_date: start_date, end_date: end_date, game_types: game_types, sport_id: sport_id).call
  end

  def initialize(start_date:, end_date:, game_types: DEFAULT_GAME_TYPES, sport_id: 1)
    @start_date = parse_date(start_date)
    @end_date = parse_date(end_date)
    @game_types = parse_game_types(game_types)
    @sport_id = Integer(sport_id, exception: false)
  end

  def call
    return failure("Start date is required") if start_date.nil?
    return failure("End date is required") if end_date.nil?
    return failure("End date must be greater than or equal to start date") if end_date < start_date
    return failure("At least one game type is required") if game_types.empty?
    return failure("Sport id must be a positive integer") if sport_id.nil? || sport_id < 1

    source_url = build_url
    payload = fetch_json(source_url)
    return failure("MLB schedule response must be a JSON object") unless payload.is_a?(Hash)

    game_count = Array(payload["dates"]).sum { |date_entry| Array(date_entry["games"]).length }

    success(
      "Downloaded #{game_count} games from the MLB schedule",
      payload: payload,
      game_count: game_count,
      start_date: start_date.iso8601,
      end_date: end_date.iso8601,
      game_types: game_types,
      sport_id: sport_id,
      source_url: source_url,
      fetched_at: Time.current.utc.iso8601
    )
  rescue JSON::ParserError => e
    failure("Failed to parse MLB schedule response: #{e.message}")
  rescue StandardError => e
    failure("Failed to download MLB schedule: #{e.message}")
  end

  private

  def parse_date(value)
    return if value.blank?

    Date.iso8601(value.to_s)
  rescue ArgumentError
    nil
  end

  def parse_game_types(value)
    Array(value.to_s.split(",")).map { |item| item.strip.upcase }.reject(&:blank?).uniq
  end

  def build_url
    query = {
      sportId: sport_id,
      startDate: start_date.iso8601,
      endDate: end_date.iso8601,
      gameTypes: game_types.join(","),
      hydrate: "team,probablePitcher,venue"
    }.to_query

    "#{service_config.fetch(:base_url)}/api/v1/schedule?#{query}"
  end

  def fetch_json(url)
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = service_config.fetch(:timeout_seconds).to_i
    http.read_timeout = service_config.fetch(:timeout_seconds).to_i

    request = Net::HTTP::Get.new(uri.request_uri)
    request["User-Agent"] = service_config.fetch(:user_agents).fetch(:schedule)
    request["Accept"] = "application/json"

    response = http.request(request)
    raise "HTTP #{response.code}: #{response.message}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
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
