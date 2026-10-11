require "json"

class MlbRosterDownloader
  DEFAULT_ROSTER_TYPE = "40Man"

  attr_reader :team_mlb_id, :season, :roster_type, :as_of

  def self.call(team_mlb_id:, season: Date.current.year, roster_type: DEFAULT_ROSTER_TYPE, as_of: Date.current)
    new(team_mlb_id: team_mlb_id, season: season, roster_type: roster_type, as_of: as_of).call
  end

  def initialize(team_mlb_id:, season: Date.current.year, roster_type: DEFAULT_ROSTER_TYPE, as_of: Date.current)
    @team_mlb_id = Integer(team_mlb_id, exception: false)
    @season = Integer(season, exception: false)
    @roster_type = roster_type.to_s.strip.presence
    @as_of = parse_date(as_of)
  end

  def call
    return failure("Team MLB id must be a positive integer") if team_mlb_id.nil? || team_mlb_id < 1
    return failure("Season must be greater than 1800") if season.nil? || season <= 1800
    return failure("Roster type is required") if roster_type.blank?
    return failure("As-of date is required") if as_of.nil?

    source_url = build_url
    payload = fetch_json(source_url)
    return failure("MLB roster response must be a JSON object") unless payload.is_a?(Hash)
    return failure("MLB roster response must include a roster array") unless payload["roster"].is_a?(Array)

    success(
      "Downloaded #{payload['roster'].length} MLB roster entries",
      payload: payload,
      entry_count: payload["roster"].length,
      team_mlb_id: team_mlb_id,
      season: season,
      roster_type: roster_type,
      as_of: as_of.iso8601,
      source_url: source_url,
      fetched_at: Time.current.utc.iso8601
    )
  rescue JSON::ParserError => e
    failure("Failed to parse MLB roster response: #{e.message}")
  rescue StandardError => e
    failure("Failed to download MLB roster: #{e.message}")
  end

  private

  def build_url
    query = {
      rosterType: roster_type,
      season: season,
      date: as_of.iso8601,
      hydrate: "person"
    }.to_query

    "#{service_config.fetch(:base_url)}/api/v1/teams/#{team_mlb_id}/roster?#{query}"
  end

  def fetch_json(url)
    MlbStatsApiClient.get_json(
      url,
      user_agent: service_config.fetch(:user_agents).fetch(:roster)
    )
  end

  def service_config
    @service_config ||= NineLensConfig.fetch(:external_services, :mlb_stats_api)
  end

  def parse_date(value)
    return value if value.is_a?(Date)
    return if value.blank?

    Date.iso8601(value.to_s)
  rescue ArgumentError
    nil
  end

  def success(message, data = {})
    { success: true, message: message, data: data }
  end

  def failure(message)
    { success: false, message: message, data: {} }
  end
end
