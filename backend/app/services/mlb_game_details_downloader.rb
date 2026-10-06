require "json"
require "net/http"

class MlbGameDetailsDownloader
  def self.call(mlb_id:)
    new(mlb_id: mlb_id).call
  end

  def initialize(mlb_id:)
    @mlb_id = Integer(mlb_id, exception: false)
  end

  def call
    return failure("MLB game id must be a positive integer") unless mlb_id&.positive?

    fetched_at = Time.current.utc.iso8601
    base_url = service_config.fetch(:base_url)
    boxscore_url = "#{base_url}/api/v1/game/#{mlb_id}/boxscore"
    live_feed_url = "#{base_url}/api/v1.1/game/#{mlb_id}/feed/live"
    boxscore = fetch_json(boxscore_url)
    live_feed = fetch_json(live_feed_url)
    validate_live_feed_game!(live_feed)

    success(
      "Downloaded MLB game details for #{mlb_id}",
      mlb_id: mlb_id,
      boxscore: boxscore,
      live_feed: live_feed,
      boxscore_source_url: boxscore_url,
      live_feed_source_url: live_feed_url,
      fetched_at: fetched_at
    )
  rescue JSON::ParserError => e
    failure("Failed to parse MLB game #{mlb_id} details: #{e.message}")
  rescue StandardError => e
    failure("Failed to download MLB game #{mlb_id} details: #{e.message}")
  end

  private

  attr_reader :mlb_id

  def fetch_json(url)
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = service_config.fetch(:timeout_seconds).to_i
    http.read_timeout = service_config.fetch(:timeout_seconds).to_i

    request = Net::HTTP::Get.new(uri.request_uri)
    request["User-Agent"] = service_config.fetch(:user_agents).fetch(:game_details)
    request["Accept"] = "application/json"
    response = http.request(request)
    raise "HTTP #{response.code}: #{response.message}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end

  def validate_live_feed_game!(live_feed)
    live_game_id = Integer(live_feed["gamePk"], exception: false)
    return if live_game_id == mlb_id

    returned_id = live_game_id || "unknown"
    raise "MLB live feed returned game #{returned_id} for requested game #{mlb_id}"
  end

  def service_config
    @service_config ||= NineLensConfig.fetch(:external_services, :mlb_stats_api)
  end

  def success(message, data)
    { success: true, message: message, data: data }
  end

  def failure(message)
    { success: false, message: message, data: {} }
  end
end
