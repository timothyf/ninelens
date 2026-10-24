require "json"

class MlbLivePitchDataDownloader
  AVAILABLE_STATUSES = %w[live final complete].freeze

  def self.call(game:)
    new(game: game).call
  end

  def initialize(game:)
    @game = game
  end

  def call
    return failure("Game must be a persisted Game record") unless game.is_a?(Game) && game.mlb_id.present?
    return success([], "Game has not started") unless AVAILABLE_STATUSES.include?(game.status.to_s.downcase)

    live_feed = fetch_json(live_feed_url)
    rows = build_rows(live_feed)
    success(rows, "Downloaded #{rows.length} live Statcast pitch rows for #{game.mlb_id}")
  rescue JSON::ParserError => e
    cached_result_or_failure("Failed to parse live MLB game #{game.mlb_id} pitch data: #{e.message}")
  rescue StandardError => e
    cached_result_or_failure("Failed to download live MLB game #{game.mlb_id} pitch data: #{e.message}")
  end

  private

  attr_reader :game

  def live_feed_url
    "#{service_config.fetch(:base_url)}/api/v1.1/game/#{game.mlb_id}/feed/live"
  end

  def fetch_json(url)
    MlbStatsApiClient.get_json(url, user_agent: service_config.fetch(:user_agents).fetch(:game_details))
  end

  def cached_result_or_failure(message)
    cached_feed = game.live_feed_raw_data.to_h
    if Integer(cached_feed["gamePk"], exception: false) == game.mlb_id
      rows = build_rows(cached_feed)
      return success(rows, "Loaded #{rows.length} pitch rows from saved MLB live feed for #{game.mlb_id}") if rows.any?
    end

    failure(message)
  end

  def build_rows(live_feed)
    fetched_at = Time.current.utc.iso8601
    Array(live_feed.dig("liveData", "plays", "allPlays")).flat_map do |play|
      base = play_row(play, fetched_at)
      next [] if base.nil?

      pitch_events = Array(play["playEvents"]).select do |event|
        event["isPitch"] == true || event["pitchNumber"].present? || event.dig("details", "type", "code").present?
      end
      pitch_events.map.with_index do |event, index|
        result_event = index == pitch_events.length - 1 ? play.dig("result", "event") : nil
        base.merge(pitch_event_row(event, index, result_event: result_event))
      end
    end
  end

  def play_row(play, fetched_at)
    at_bat_index = integer(play.dig("about", "atBatIndex"))
    batter = integer(play.dig("matchup", "batter", "id"))
    pitcher = integer(play.dig("matchup", "pitcher", "id"))
    return if at_bat_index.nil? || batter.nil? || pitcher.nil?

    {
      "source_start_date" => game.official_date.iso8601,
      "source_end_date" => game.official_date.iso8601,
      "fetched_at_utc" => fetched_at,
      "game_date" => game.official_date.iso8601,
      "game_year" => game.official_date.year,
      "game_pk" => game.mlb_id.to_s,
      "game_type" => game.game_type,
      "home_team" => game.home_team&.abbreviation,
      "away_team" => game.away_team&.abbreviation,
      "inning" => play.dig("about", "inning"),
      "inning_topbot" => play.dig("about", "halfInning"),
      "at_bat_number" => at_bat_index + 1,
      "pitcher" => pitcher,
      "player_name" => play.dig("matchup", "pitcher", "fullName"),
      "batter" => batter,
      "stand" => play.dig("matchup", "batSide", "code"),
      "p_throws" => play.dig("matchup", "pitchHand", "code")
    }
  end

  def pitch_event_row(event, fallback_pitch_number, result_event: nil)
    details = event.fetch("details", {})
    hit_data = event.fetch("hitData", {})
    hit_coordinates = hit_data.fetch("coordinates", {})
    pitch_data = event.fetch("pitchData", {})
    coordinates = pitch_data.fetch("coordinates", {})
    breaks = pitch_data.fetch("breaks", {})
    pitch_type = details.fetch("type", {})

    {
      "pitch_number" => event["pitchNumber"] || fallback_pitch_number + 1,
      "pitch_type" => pitch_type["code"],
      "pitch_name" => pitch_type["description"],
      "description" => details["description"],
      "events" => normalized_event(details["event"].presence || result_event),
      "zone" => pitch_data["zone"],
      "release_speed" => pitch_data["startSpeed"],
      "plate_x" => coordinates["pX"],
      "plate_z" => coordinates["pZ"],
      "pfx_x" => coordinates["pfxX"],
      "pfx_z" => coordinates["pfxZ"],
      "spin_axis" => breaks["spinAxis"],
      "break_angle_deprecated" => breaks["breakAngle"],
      "break_length_deprecated" => breaks["breakLength"],
      "balls" => event.dig("count", "balls"),
      "strikes" => event.dig("count", "strikes"),
      "outs_when_up" => event.dig("count", "outs"),
      "launch_speed" => hit_data["launchSpeed"],
      "launch_angle" => hit_data["launchAngle"],
      "launch_speed_angle" => hit_data["launchSpeedAngle"],
      "hit_distance_sc" => hit_data["totalDistance"],
      "bb_type" => hit_data["trajectory"],
      "hc_x" => hit_coordinates["coordX"],
      "hc_y" => hit_coordinates["coordY"],
      "bat_speed" => hit_data["batSpeed"],
      "raw_live_feed_event" => event
    }
  end

  def normalized_event(event)
    event.to_s.parameterize(separator: "_").presence
  end

  def integer(value)
    Integer(value, exception: false)
  end

  def service_config
    @service_config ||= NineLensConfig.fetch(:external_services, :mlb_stats_api)
  end

  def success(rows, message)
    { success: true, message: message, rows: rows }
  end

  def failure(message)
    { success: false, message: message, rows: [] }
  end
end
