class MlbGameDetailsImporter
  SOURCE_NAME = "MLB Stats API"
  SUBSTITUTION_EVENT_TYPES = %w[
    offensive_substitution defensive_substitution pitching_substitution
    defensive_switch pitcher_switch substitution
  ].freeze

  class ImportError < StandardError; end

  def self.call(game:, boxscore:, live_feed:, boxscore_source_url: nil, live_feed_source_url: nil, fetched_at: Time.current)
    new(
      game: game,
      boxscore: boxscore,
      live_feed: live_feed,
      boxscore_source_url: boxscore_source_url,
      live_feed_source_url: live_feed_source_url,
      fetched_at: fetched_at
    ).call
  end

  def initialize(game:, boxscore:, live_feed:, boxscore_source_url: nil, live_feed_source_url: nil, fetched_at: Time.current)
    @game = game
    @boxscore = boxscore
    @live_feed = live_feed
    @boxscore_source_url = boxscore_source_url
    @live_feed_source_url = live_feed_source_url
    @fetched_at = parse_time(fetched_at)
    @players_by_mlb_id = {}
  end

  def call
    return failure("Game detail import validation failed", input_errors) if input_errors.any?

    counts = persist!
    success(
      "Synchronized details for MLB game #{game.mlb_id}",
      counts.merge(game_id: game.id, mlb_id: game.mlb_id)
    )
  rescue ImportError => e
    failure("Game detail import validation failed", [ e.message ])
  rescue ActiveRecord::ActiveRecordError => e
    failure("Failed to import MLB game #{game.mlb_id} details: #{e.message}")
  end

  private

  attr_reader :game, :boxscore, :live_feed, :boxscore_source_url, :live_feed_source_url, :fetched_at, :players_by_mlb_id

  def input_errors
    errors = []
    errors << "Game is required" unless game.is_a?(Game)
    errors << "Box score must be a JSON object" unless boxscore.is_a?(Hash)
    errors << "Live feed must be a JSON object" unless live_feed.is_a?(Hash)
    errors << "Fetched-at timestamp is required" if fetched_at.nil?
    errors
  end

  def persist!
    counts = {
      batting_line_count: 0,
      pitching_line_count: 0,
      lineup_entry_count: 0,
      plate_appearance_count: 0,
      created_player_count: 0,
      linked_pitch_count: 0
    }

    Game.transaction do
      game.update!(
        status: live_game_status,
        detailed_status: live_detailed_status,
        home_score: live_score("home") || game.home_score,
        away_score: live_score("away") || game.away_score,
        game_number: parse_integer(live_feed.dig("gameData", "game", "gameNumber")) || game.game_number,
        doubleheader: live_feed.dig("gameData", "game", "doubleHeader").presence || game.doubleheader,
        details_source_url: live_feed_source_url,
        details_last_synced_at: fetched_at,
        boxscore_raw_data: boxscore,
        live_feed_raw_data: live_feed
      )

      %w[away home].each do |side|
        import_team_boxscore!(side, counts)
      end
      import_plate_appearances!(counts)
      counts[:linked_pitch_count] = link_pitches!
    end

    counts
  end

  def effective_boxscore
    @effective_boxscore ||= boxscore.presence || live_feed.dig("liveData", "boxscore") || {}
  end

  def live_detailed_status
    live_feed.dig("gameData", "status", "detailedState").presence || game.detailed_status
  end

  def live_game_status
    detail = live_detailed_status.to_s.downcase
    return "postponed" if detail.include?("postponed")
    return "suspended" if detail.include?("suspended")

    live_feed.dig("gameData", "status", "abstractGameState").to_s.parameterize.presence || game.status
  end

  def live_score(side)
    parse_integer(live_feed.dig("liveData", "linescore", "teams", side, "runs"))
  end

  def team_boxscore(side)
    effective_boxscore.dig("teams", side) || live_feed.dig("liveData", "boxscore", "teams", side) || {}
  end

  def import_team_boxscore!(side, counts)
    payload = team_boxscore(side)
    team = side == "home" ? game.home_team : game.away_team
    opponent = side == "home" ? game.away_team : game.home_team
    home = side == "home"
    batter_ids = Array(payload["batters"]).filter_map { |id| parse_integer(id) }
    pitcher_ids = Array(payload["pitchers"]).filter_map { |id| parse_integer(id) }
    batting_order_ids = Array(payload["battingOrder"]).filter_map { |id| parse_integer(id) }

    # A later official box score can remove a player that was present in an
    # earlier/live payload. Upserting the new payload alone leaves that stale
    # line contributing to season totals (for example, one extra hit allowed).
    prune_stale_game_lines!(
      home: home,
      batter_ids: batter_ids,
      pitcher_ids: pitcher_ids,
      authoritative_batters: payload.key?("batters"),
      authoritative_pitchers: payload.key?("pitchers")
    )

    payload.fetch("players", {}).each_value do |player_payload|
      mlb_id = parse_integer(player_payload.dig("person", "id"))
      next if mlb_id.nil?

      player, created = resolve_player(player_payload["person"], team)
      counts[:created_player_count] += 1 if created
      stats = player_payload.fetch("stats", {})
      season_stats = player_payload.fetch("seasonStats", {})

      if batter_ids.include?(mlb_id) || stats.fetch("batting", {}).present?
        upsert_batting_line!(
          player,
          player_payload,
          stats.fetch("batting", {}),
          season_stats.fetch("batting", {}),
          team,
          opponent,
          home
        )
        counts[:batting_line_count] += 1
      end

      if pitcher_ids.include?(mlb_id) || stats.fetch("pitching", {}).present?
        upsert_pitching_line!(
          player,
          player_payload,
          stats.fetch("pitching", {}),
          season_stats.fetch("pitching", {}),
          team,
          opponent,
          home,
          pitcher_ids
        )
        counts[:pitching_line_count] += 1
      end

      if batting_order_ids.include?(mlb_id) || player_payload["battingOrder"].present?
        upsert_lineup_entry!(player, player_payload, team)
        counts[:lineup_entry_count] += 1
      end
    end
  end

  def prune_stale_game_lines!(home:, batter_ids:, pitcher_ids:, authoritative_batters:, authoritative_pitchers:)
    if authoritative_batters
      game.game_player_batting_lines.where(home:).where.not(player_id: player_ids_for(batter_ids)).delete_all
    end
    if authoritative_pitchers
      game.game_player_pitching_lines.where(home:).where.not(player_id: player_ids_for(pitcher_ids)).delete_all
    end
  end

  def player_ids_for(mlb_ids)
    Player.where(mlb_id: mlb_ids).pluck(:id)
  end

  def upsert_batting_line!(player, player_payload, stats, season_stats, team, opponent, home)
    batting_order = parse_integer(player_payload["battingOrder"])
    line = game.game_player_batting_lines.find_or_initialize_by(player: player)
    line.assign_attributes(
      team: team,
      opponent_team: opponent,
      home: home,
      starter: starter_from_order?(batting_order),
      batting_order: batting_order,
      position: player_payload.dig("position", "abbreviation"),
      plate_appearances: integer_stat(stats, "plateAppearances"),
      at_bats: integer_stat(stats, "atBats"),
      runs: integer_stat(stats, "runs"),
      hits: integer_stat(stats, "hits"),
      doubles: integer_stat(stats, "doubles"),
      triples: integer_stat(stats, "triples"),
      home_runs: integer_stat(stats, "homeRuns"),
      runs_batted_in: integer_stat(stats, "rbi"),
      walks: integer_stat(stats, "baseOnBalls"),
      strikeouts: integer_stat(stats, "strikeOuts"),
      stolen_bases: integer_stat(stats, "stolenBases"),
      caught_stealing: integer_stat(stats, "caughtStealing"),
      batting_average: decimal_stat(season_stats, "avg") || decimal_stat(stats, "avg"),
      on_base_percentage: decimal_stat(season_stats, "obp") || decimal_stat(stats, "obp"),
      slugging_percentage: decimal_stat(season_stats, "slg") || decimal_stat(stats, "slg"),
      ops: decimal_stat(season_stats, "ops") || decimal_stat(stats, "ops"),
      source_name: SOURCE_NAME,
      source_url: boxscore_source_url,
      last_synced_at: fetched_at,
      raw_data: player_payload
    )
    line.save!
  end

  def upsert_pitching_line!(player, player_payload, stats, season_stats, team, opponent, home, pitcher_ids)
    innings = stats["inningsPitched"]
    line = game.game_player_pitching_lines.find_or_initialize_by(player: player)
    line.assign_attributes(
      team: team,
      opponent_team: opponent,
      home: home,
      starter: pitcher_ids.first == player.mlb_id,
      appearance_order: pitcher_ids.index(player.mlb_id)&.+(1),
      innings_pitched: innings,
      outs_recorded: innings_to_outs(innings),
      batters_faced: integer_stat(stats, "battersFaced"),
      hits: integer_stat(stats, "hits"),
      runs: integer_stat(stats, "runs"),
      earned_runs: integer_stat(stats, "earnedRuns"),
      home_runs: integer_stat(stats, "homeRuns"),
      walks: integer_stat(stats, "baseOnBalls"),
      strikeouts: integer_stat(stats, "strikeOuts"),
      pitches: integer_stat(stats, "numberOfPitches"),
      strikes: integer_stat(stats, "strikes"),
      era: decimal_stat(season_stats, "era") || decimal_stat(stats, "era"),
      whip: decimal_stat(season_stats, "whip") || decimal_stat(stats, "whip"),
      decision: stats["note"],
      holds: integer_stat(stats, "holds"),
      saves: integer_stat(stats, "saves"),
      blown_saves: integer_stat(stats, "blownSaves"),
      source_name: SOURCE_NAME,
      source_url: boxscore_source_url,
      last_synced_at: fetched_at,
      raw_data: player_payload
    )
    line.save!
  end

  def upsert_lineup_entry!(player, player_payload, team)
    batting_order = parse_integer(player_payload["battingOrder"])
    entry = game.lineup_entries.find_or_initialize_by(team: team, player: player)
    entry.assign_attributes(
      batting_order: batting_order,
      batting_slot: batting_order&./(100),
      starter: starter_from_order?(batting_order),
      position: player_payload.dig("position", "abbreviation"),
      all_positions: Array(player_payload["allPositions"]),
      substitutions: substitution_events[player.mlb_id] || [],
      source_name: SOURCE_NAME,
      source_url: live_feed_source_url,
      last_synced_at: fetched_at,
      raw_data: player_payload
    )
    entry.save!
  end

  def import_plate_appearances!(counts)
    Array(live_feed.dig("liveData", "plays", "allPlays")).each do |play|
      at_bat_index = parse_integer(play.dig("about", "atBatIndex"))
      next if at_bat_index.nil?

      half = play.dig("about", "halfInning").to_s.downcase
      batting_team = half == "top" ? game.away_team : game.home_team
      fielding_team = half == "top" ? game.home_team : game.away_team
      batter, batter_created = resolve_player(play.dig("matchup", "batter"), batting_team)
      pitcher, pitcher_created = resolve_player(play.dig("matchup", "pitcher"), fielding_team)
      counts[:created_player_count] += 1 if batter_created
      counts[:created_player_count] += 1 if pitcher_created
      plate_appearance = game.plate_appearances.find_or_initialize_by(at_bat_index: at_bat_index)
      plate_appearance.assign_attributes(
        plate_appearance_number: at_bat_index + 1,
        batter: batter,
        pitcher: pitcher,
        batting_team: batting_team,
        fielding_team: fielding_team,
        inning: parse_integer(play.dig("about", "inning")),
        half_inning: play.dig("about", "halfInning"),
        event: play.dig("result", "event"),
        event_type: play.dig("result", "eventType"),
        description: play.dig("result", "description"),
        runs_batted_in: parse_integer(play.dig("result", "rbi")),
        away_score: parse_integer(play.dig("result", "awayScore")),
        home_score: parse_integer(play.dig("result", "homeScore")),
        outs_after: parse_integer(play.dig("count", "outs")),
        complete: play.dig("about", "isComplete") == true,
        started_at: parse_time(play.dig("about", "startTime")),
        ended_at: parse_time(play.dig("about", "endTime")),
        source_name: SOURCE_NAME,
        source_url: live_feed_source_url,
        last_synced_at: fetched_at,
        raw_data: play
      )
      plate_appearance.save!
      counts[:plate_appearance_count] += 1
    end
  end

  def resolve_player(person_payload, team)
    mlb_id = parse_integer(person_payload&.fetch("id", nil))
    return [ nil, false ] if mlb_id.nil?
    return [ players_by_mlb_id[mlb_id], false ] if players_by_mlb_id.key?(mlb_id)

    player = Player.find_or_initialize_by(mlb_id: mlb_id)
    created = player.new_record?
    if created
      first_name, last_name = person_names(person_payload)
      player.assign_attributes(first_name: first_name, last_name: last_name, team: team)
      player.save!
    end
    players_by_mlb_id[mlb_id] = player
    [ player, created ]
  end

  def person_names(payload)
    first_name = payload["firstName"].presence
    last_name = payload["lastName"].presence
    return [ first_name, last_name ] if first_name && last_name

    parts = payload["fullName"].to_s.strip.split
    return [ parts[0...-1].join(" "), parts.last ] if parts.length > 1

    [ "Unknown", parts.first.presence || "Player" ]
  end

  def substitution_events
    @substitution_events ||= Array(live_feed.dig("liveData", "plays", "allPlays")).flat_map do |play|
      Array(play["playEvents"])
    end.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |event, grouped|
      event_type = event.dig("details", "eventType").to_s
      next unless SUBSTITUTION_EVENT_TYPES.include?(event_type) || event_type.include?("substitution")

      player_id = parse_integer(event.dig("details", "player", "id") || event.dig("player", "id"))
      grouped[player_id] << event if player_id
    end
  end

  def link_pitches!
    linked = 0
    game.plate_appearances.find_each do |plate_appearance|
      linked += PitchDatum
        .where(game_pk: game.mlb_id, at_bat_number: plate_appearance.plate_appearance_number)
        .where("plate_appearance_id IS NULL OR plate_appearance_id <> ? OR game_id IS NULL OR game_id <> ?", plate_appearance.id, game.id)
        .update_all(game_id: game.id, plate_appearance_id: plate_appearance.id, updated_at: Time.current)
    end
    linked
  end

  def starter_from_order?(batting_order)
    batting_order.present? && (batting_order % 100).zero?
  end

  def integer_stat(stats, key)
    parse_integer(stats[key])
  end

  def decimal_stat(stats, key)
    BigDecimal(stats[key].to_s, exception: false)
  end

  def innings_to_outs(value)
    return if value.blank?

    whole, partial = value.to_s.split(".", 2)
    (whole.to_i * 3) + partial.to_i
  end

  def parse_integer(value)
    Integer(value, exception: false)
  end

  def parse_time(value)
    return if value.blank?
    return value.in_time_zone if value.respond_to?(:in_time_zone)

    Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def success(message, data)
    { success: true, message: message, data: data }
  end

  def failure(message, errors = [])
    { success: false, message: message, data: { errors: errors } }
  end
end
