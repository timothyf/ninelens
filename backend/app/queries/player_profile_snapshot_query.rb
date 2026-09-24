class PlayerProfileSnapshotQuery
  PITCH_SAMPLE_SIZE = 100
  HIT_EVENTS = %w[single double triple home_run].freeze
  SEASON_CATEGORIES = %w[batting pitching].freeze
  BATTING_RATE_KEYS = %w[avg obp slg ops].freeze
  PITCHING_RATE_KEYS = %w[ERA whip avg].freeze
  AUTHORITATIVE_RATE_STAT_NAMES = {
    "batting" => %w[avg AVG obp OBP slg SLG ops OPS].freeze,
    "pitching" => %w[ERA era whip WHIP avg AVG].freeze
  }.freeze
  COMPARISON_RATE_METRICS = [
    { key: :k_percentage, label: "K%" },
    { key: :bb_percentage, label: "BB%" }
  ].freeze
  ADVANCED_BATTING_GROUPS = [
    {
      key: "plate_discipline",
      label: "Plate discipline",
      columns: [
        { key: "swing_percentage", label: "Swing%", unit: "percent" },
        { key: "chase_percentage", label: "Chase%", unit: "percent" },
        { key: "contact_percentage", label: "Contact%", unit: "percent" },
        { key: "zone_contact_percentage", label: "Zone Contact%", unit: "percent" },
        { key: "swinging_strike_percentage", label: "SwStr%", unit: "percent" }
      ]
    },
    {
      key: "batted_ball_profile",
      label: "Batted-ball profile",
      columns: [
        { key: "ground_ball_percentage", label: "GB%", unit: "percent" },
        { key: "fly_ball_percentage", label: "FB%", unit: "percent" },
        { key: "line_drive_percentage", label: "LD%", unit: "percent" },
        { key: "pull_percentage", label: "Pull%", unit: "percent" },
        { key: "center_percentage", label: "Center%", unit: "percent" },
        { key: "opposite_field_percentage", label: "Opposite-field%", unit: "percent" }
      ]
    },
    {
      key: "rate_statistics",
      label: "Rate statistics",
      columns: [
        { key: "bb_percentage", label: "BB%", unit: "percent" },
        { key: "k_percentage", label: "K%", unit: "percent" },
        { key: "bb_per_k", label: "BB/K", unit: "ratio" },
        { key: "iso", label: "ISO", unit: "rate" },
        { key: "babip", label: "BABIP", unit: "rate" },
        { key: "hr_per_fly_ball", label: "HR/FB%", unit: "percent" }
      ]
    },
    {
      key: "run_creation_value",
      label: "Run Creation & Value",
      columns: [
        { key: "woba", label: "wOBA", unit: "rate" },
        { key: "wrc_plus", label: "wRC+", unit: "index" },
        { key: "ops_plus", label: "OPS+", unit: "index" },
        { key: "offensive_runs", label: "Offensive Runs", unit: "runs" },
        { key: "baserunning_runs", label: "Baserunning Runs", unit: "runs" },
        { key: "defensive_value", label: "Defensive Value", unit: "runs" },
        { key: "war", label: "WAR", unit: "war" }
      ]
    },
  ].freeze
  ADVANCED_PITCHING_GROUPS = [
    {
      key: "rate_and_outcome_statistics",
      label: "Rate and outcome statistics",
      columns: [
        { key: "k_percentage", label: "K%", unit: "percent" },
        { key: "bb_percentage", label: "BB%", unit: "percent" },
        { key: "k_minus_bb_percentage", label: "K-BB%", unit: "percent" },
        { key: "k_per_bb", label: "K/BB", unit: "ratio" },
        { key: "hbp_percentage", label: "HBP%", unit: "percent" },
        { key: "hr_percentage", label: "HR%", unit: "percent" },
        { key: "babip", label: "BABIP", unit: "rate" },
        { key: "lob_percentage", label: "LOB%", unit: "percent" },
        { key: "era", label: "ERA", unit: "pitching_rate" },
        { key: "fip", label: "FIP", unit: "pitching_rate" },
        { key: "xfip", label: "xFIP", unit: "pitching_rate" }
      ]
    },
    {
      key: "run_prevention_and_expected_performance",
      label: "Run prevention and expected performance",
      columns: [
        { key: "era", label: "ERA", unit: "pitching_rate" },
        { key: "era_minus", label: "ERA-", unit: "index" },
        { key: "era_plus", label: "ERA+", unit: "index" },
        { key: "fip", label: "FIP", unit: "pitching_rate" },
        { key: "fip_minus", label: "FIP-", unit: "index" },
        { key: "xfip", label: "xFIP", unit: "pitching_rate" },
        { key: "xfip_minus", label: "xFIP-", unit: "index" },
        { key: "siera", label: "SIERA", unit: "pitching_rate" },
        { key: "xera", label: "xERA", unit: "pitching_rate" },
        { key: "ra9", label: "RA9", unit: "pitching_rate" },
        { key: "runs_allowed_per_nine", label: "Runs allowed per 9", unit: "pitching_rate" },
        { key: "earned_runs_allowed_per_nine", label: "Earned runs allowed per 9", unit: "pitching_rate" },
        { key: "expected_woba_allowed", label: "Expected wOBA allowed", unit: "rate" },
        { key: "woba_allowed", label: "wOBA allowed", unit: "rate" }
      ]
    },
    {
      key: "pitcher_value",
      label: "Pitcher value",
      description: "A high-level summary of how much value the pitcher produced.",
      columns: [
        { key: "war", label: "WAR", unit: "war" },
        { key: "ra9_war", label: "RA9-WAR", unit: "war" },
        { key: "wpa", label: "WPA", unit: "war" },
        { key: "wpa_per_li", label: "WPA/LI", unit: "war" },
        { key: "re24", label: "RE24", unit: "runs" },
        { key: "clutch", label: "Clutch", unit: "ratio" },
        { key: "runs_above_replacement", label: "Runs above replacement", unit: "runs" },
        { key: "runs_above_average", label: "Runs above average", unit: "runs" },
        { key: "pitching_runs", label: "Pitching runs", unit: "runs" },
        { key: "leverage_index", label: "Leverage index", unit: "ratio" },
        { key: "shutdowns", label: "Shutdowns", unit: "count" },
        { key: "meltdowns", label: "Meltdowns", unit: "count" }
      ]
    }
  ].freeze
  TRANSACTION_HISTORY_SOURCE_NAME = "MLB Stats API transactions"
  DEFERRED_SECTIONS = %w[advanced_stats defensive_stats splits similar_players analytics].freeze
  NON_DEFENSIVE_POSITIONS = %w[DH].freeze

  def initialize(player:, on: Date.current, analysis_range: nil, similarity_options: {})
    @player = player
    @on = on
    @analysis_range = analysis_range || PlayerAnalysisRange.resolve(player: player)
    @similarity_options = similarity_options.to_h.symbolize_keys
  end

  def result(sections: nil)
    selected_sections = sections.nil? ? DEFERRED_SECTIONS : Array(sections) & DEFERRED_SECTIONS
    payload = {
      season_overview: season_overview,
      career_overview: career_overview,
      game_logs: game_logs,
      display_team: serialize_team(display_team),
      external_ids: external_ids,
      current_membership: serialize_membership(current_membership),
      team_history: organization_tenures,
      trades: trade_history,
      analysis: { range: analysis_range.to_h },
      source_metadata: source_metadata
    }

    payload[:advanced_stats] = advanced_stats if selected_sections.include?("advanced_stats")
    payload[:defensive_stats] = defensive_stats if selected_sections.include?("defensive_stats")
    if selected_sections.include?("splits")
      payload[:batter_splits] = batter_splits_payload
      payload[:pitcher_splits] = pitcher_splits_payload
    end
    if selected_sections.include?("similar_players")
      payload[:similar_players] = SimilarPlayersQuery.new(
        player: player,
        season: similarity_options[:similar_season].presence || latest_season,
        category: preferred_category,
        mode: similarity_options[:similar_mode],
        min_age: similarity_options[:similar_min_age],
        max_age: similarity_options[:similar_max_age],
        position_match: similarity_options[:similar_position]
      ).result
    end
    payload.merge!(analytics_payload) if selected_sections.include?("analytics")

    payload
  end

  private

  attr_reader :player, :on, :analysis_range, :similarity_options

  def display_team
    return current_membership&.team || player.team unless retired_player?

    longest_served_team || player.team
  end

  def retired_player?
    player.profile&.raw_data.to_h["active"] == false
  end

  def external_ids
    mapping = player.player_id_mapping

    {
      baseball_reference: mapping&.baseball_reference_id,
      fangraphs: mapping&.fangraphs_id
    }
  end

  def longest_served_team
    seasons_by_team = player.player_season_stats
      .where.not(team_id: nil)
      .pluck(:team_id, :season)
      .group_by(&:first)
      .transform_values { |rows| rows.map(&:last).uniq }
    team_id, = seasons_by_team.max_by do |candidate_team_id, seasons|
      [ seasons.length, seasons.max || 0, candidate_team_id ]
    end

    Team.find_by(id: team_id) if team_id
  end

  def season_overview
    return empty_season_overview if latest_season.nil?

    available_categories = season_rows.map { |row| row.stat_type.category }.uniq & SEASON_CATEGORIES
    category = available_categories.include?(preferred_category) ? preferred_category : available_categories.first

    {
      season: latest_season,
      category: category,
      preferred_category: preferred_category,
      stats: category.present? ? serialized_season_stats(category) : [],
      comparison_stats: category.present? ? serialized_comparison_stats(category, season_rows, career: false) : []
    }
  end

  def empty_season_overview
    { season: nil, category: preferred_category, preferred_category: preferred_category, stats: [] }
  end

  def career_overview
    category = career_category
    rows = career_rows(category)
    return empty_career_overview if rows.empty?

    seasons = rows.map(&:season).uniq.sort

    {
      category: category,
      preferred_category: preferred_category,
      first_season: seasons.first,
      last_season: seasons.last,
      season_count: seasons.length,
      columns: career_columns(category),
      seasons: serialized_career_seasons(category),
      stats: serialized_career_stats(category),
      comparison_stats: serialized_comparison_stats(category, rows, career: true)
    }
  end

  def empty_career_overview
    {
      category: preferred_category,
      preferred_category: preferred_category,
      first_season: nil,
      last_season: nil,
      season_count: 0,
      columns: [],
      seasons: [],
      stats: []
    }
  end

  def game_logs
    {
      category: preferred_category,
      batting: recent_batting_game_logs,
      pitching: recent_pitching_game_logs
    }
  end

  def recent_batting_game_logs
    @recent_batting_game_logs ||= player.game_player_batting_lines
      .joins(:game, :team, :opponent_team)
      .where(games: { status: "final" })
      .includes(:game, :team, :opponent_team)
      .order("games.official_date DESC, games.scheduled_at DESC, games.mlb_id DESC")
      .limit(30)
      .map { |line| serialize_batting_game_log(line) }
  end

  def recent_pitching_game_logs
    @recent_pitching_game_logs ||= player.game_player_pitching_lines
      .joins(:game, :team, :opponent_team)
      .where(games: { status: "final" })
      .includes(:game, :team, :opponent_team)
      .order("games.official_date DESC, games.scheduled_at DESC, games.mlb_id DESC")
      .limit(15)
      .map { |line| serialize_pitching_game_log(line) }
  end

  def serialize_batting_game_log(line)
    stats = line.raw_data.to_h.fetch("stats", {})
    {
      date: line.game.official_date,
      team: line.team.abbreviation,
      opponent: opponent_label(line),
      at_bats: line.at_bats,
      runs: line.runs,
      hits: line.hits,
      total_bases: raw_integer_stat(stats, "totalBases") || total_bases(line),
      doubles: line.doubles,
      triples: line.triples,
      home_runs: line.home_runs,
      runs_batted_in: line.runs_batted_in,
      walks: line.walks,
      intentional_walks: raw_integer_stat(stats, "intentionalWalks"),
      strikeouts: line.strikeouts,
      stolen_bases: line.stolen_bases,
      caught_stealing: line.caught_stealing,
      batting_average: line.batting_average,
      on_base_percentage: line.on_base_percentage,
      slugging_percentage: line.slugging_percentage,
      hit_by_pitch: raw_integer_stat(stats, "hitByPitch"),
      sacrifice_hits: raw_integer_stat(stats, "sacBunts"),
      sacrifice_flies: raw_integer_stat(stats, "sacFlies")
    }
  end

  def serialize_pitching_game_log(line)
    stats = line.raw_data.to_h.fetch("stats", {})
    {
      date: line.game.official_date,
      team: line.team.abbreviation,
      opponent: opponent_label(line),
      decision: line.decision,
      wins: raw_integer_stat(stats, "wins") || (line.decision.to_s.casecmp("W").zero? ? 1 : nil),
      losses: raw_integer_stat(stats, "losses") || (line.decision.to_s.casecmp("L").zero? ? 1 : nil),
      era: line.era,
      games: 1,
      games_started: line.starter ? 1 : 0,
      complete_games: raw_integer_stat(stats, "completeGames"),
      shutouts: raw_integer_stat(stats, "shutouts"),
      saves: line.saves,
      save_opportunities: raw_integer_stat(stats, "saveOpportunities"),
      innings_pitched: line.innings_pitched,
      hits: line.hits,
      runs: line.runs,
      earned_runs: line.earned_runs,
      home_runs: line.home_runs,
      hit_batters: raw_integer_stat(stats, "hitBatsmen"),
      walks: line.walks,
      intentional_walks: raw_integer_stat(stats, "intentionalWalks"),
      strikeouts: line.strikeouts,
      pitches_strikes: [line.pitches, line.strikes].compact.join("-").presence,
      batting_average: raw_decimal_stat(stats, "avg"),
      whip: line.whip,
      go_ao: raw_decimal_stat(stats, "goao") || raw_decimal_stat(stats, "goA")
    }
  end

  def opponent_label(line)
    line.home ? "@ #{line.opponent_team.abbreviation}" : "vs #{line.opponent_team.abbreviation}"
  end

  def total_bases(line)
    line.hits.to_i + line.doubles.to_i + (line.triples.to_i * 2) + (line.home_runs.to_i * 3) if line.hits.present?
  end

  def raw_integer_stat(stats, key)
    value = stats[key] || stats[key.to_sym]
    Integer(value, exception: false)
  end

  def raw_decimal_stat(stats, key)
    value = stats[key] || stats[key.to_sym]
    Float(value, exception: false)
  end

  def advanced_stats
    category = career_category
    groups = advanced_groups(category)
    return empty_advanced_stats if groups.empty?

    seasons = career_rows_by_season(category).sort.map do |season, rows|
      team_rows = team_rows_for_season(rows)
      {
        season: season,
        teams: rows.filter_map(&:team).uniq(&:id).map { |team| serialize_team(team) },
        values: advanced_values(category, rows),
        team_rows: team_rows.map do |team, team_stats|
          { team: serialize_team(team), values: advanced_team_values(category, team_stats, rows) }
        end,
        total_values: advanced_values(category, rows)
      }
    end

    {
      category: category,
      groups: groups,
      seasons: seasons,
      career: { values: advanced_values(category, career_rows(category), career: true) }
    }
  end

  def empty_advanced_stats
    { category: preferred_category, groups: advanced_groups(preferred_category), seasons: [], career: { values: {} } }
  end

  def defensive_stats
    seasons = all_season_rows.map(&:season).compact.uniq.sort
    rows = seasons.map { |season| defensive_season_stats(season) }
    { season: latest_season, seasons: rows }
  end

  def defensive_season_stats(season)
    stat_rows = all_season_rows.select { |row| row.season == season }
    games = advanced_count(stat_rows, %w[gamesPlayed G games], career: false)
    stored_positions = stored_fielding_positions(season)
    game_fielding = game_fielding_summary(season)
    assignments = player.player_positions.to_a
      .reject { |assignment| non_defensive_position?(assignment.position.abbreviation) }
      .select { |assignment| assignment.season.nil? || assignment.season == season }
      .sort_by { |assignment| [assignment.is_primary? ? 0 : 1, assignment.position.sort_order] }
      .uniq { |assignment| assignment.position_id }

    stored_fielding_percentage = advanced_rate(
      stat_rows,
      %w[fieldingPercentage fieldingPct fielding_percentage fldgPct FPCT FldgPct],
      %w[gamesPlayed G games],
      career: false
    )
    fielding_percentage = stored_fielding_percentage
    fielding_percentage = stored_position_fielding_percentage(season) if fielding_percentage.nil?
    fielding_percentage ||= game_fielding[:fielding_percentage]

    {
      season: season,
      games: games || game_fielding[:positions].sum { |entry| entry[:games].to_i },
      outs_above_average_applicable: player.primary_position&.position_type != "pitcher",
      positions: (stored_positions.presence || game_fielding[:positions].presence || assignments.map.with_index do |assignment, index|
        { position: assignment.position.abbreviation || assignment.position.name, games: index.zero? ? games : nil, innings: nil }
      end),
      fielding_percentage: numeric_advanced_value(fielding_percentage),
      defensive_runs_saved: numeric_advanced_value(
        advanced_count(stat_rows, %w[defensiveRunsSaved DRS drs], career: false) || summed_position_metric(stored_positions, :defensive_runs_saved) || game_fielding[:defensive_runs_saved]
      ),
      outs_above_average: numeric_advanced_value(
        advanced_count(stat_rows, %w[outsAboveAverage OAA oaa outs_above_average], career: false) || summed_position_metric(stored_positions, :outs_above_average) || game_fielding[:outs_above_average]
      )
    }
  end

  def stored_fielding_positions(season)
    stored_fielding_rows(season)
      .group_by(&:position)
      .map do |position, rows|
        putouts = rows.filter_map(&:putouts).sum
        assists = rows.filter_map(&:assists).sum
        fielding_errors = rows.filter_map(&:fielding_errors).sum
        chances = putouts + assists + fielding_errors
        innings_outs = rows.filter_map(&:innings).sum { |innings| innings_to_outs(innings) }

        {
          position: position,
          games: rows.filter_map(&:games).sum,
          innings: innings_outs.positive? ? format_innings(innings_outs) : nil,
          fielding_percentage: numeric_advanced_value(
            chances.positive? ? (putouts + assists).to_d / chances : rows.filter_map(&:fielding_percentage).first
          ),
          defensive_runs_saved: numeric_advanced_value(summed_fielding_value(rows, :defensive_runs_saved)),
          outs_above_average: numeric_advanced_value(summed_fielding_value(rows, :outs_above_average))
        }
      end
      .sort_by { |row| [ -row[:games].to_i, row[:position] ] }
  end

  def summed_fielding_value(rows, attribute)
    values = rows.filter_map { |row| row.public_send(attribute) }
    values.any? ? values.sum : nil
  end

  def summed_position_metric(rows, key)
    values = rows.filter_map { |row| row[key] }
    values.any? ? values.sum : nil
  end
  def stored_position_fielding_percentage(season)
    rows = stored_fielding_rows(season)
    putouts = rows.filter_map(&:putouts).sum
    assists = rows.filter_map(&:assists).sum
    fielding_errors = rows.filter_map(&:fielding_errors).sum
    chances = putouts + assists + fielding_errors
    return (putouts + assists).to_d / chances if chances.positive?

    rows.filter_map(&:fielding_percentage).first
  end

  def stored_fielding_rows(season)
    @stored_fielding_rows ||= {}
    @stored_fielding_rows[season] ||= player.player_season_fielding_stats
      .where(season: season)
      .to_a
      .reject { |row| non_defensive_position?(row.position) }
  end

  def non_defensive_position?(position)
    NON_DEFENSIVE_POSITIONS.include?(position.to_s.strip.upcase)
  end



  def game_fielding_summary(season)
    lines = player.game_player_batting_lines
      .joins(:game)
      .where(games: { status: "final" })
      .where(games: { official_date: Date.new(season, 1, 1)..Date.new(season, 12, 31) })
      .to_a
    grouped = lines.group_by { |line| line.position.presence || "—" }
    grouped.reject! { |position, _lines| non_defensive_position?(position) }
    position_rows = grouped.map do |position, position_lines|
      fielding = position_lines.filter_map { |line| line.raw_data.to_h.dig("stats", "fielding") }
      innings = fielding.sum { |stats| Float(stats["innings"], exception: false) || 0.0 }
      {
        position: position,
        games: position_lines.map(&:game_id).uniq.length,
        innings: innings.positive? ? innings : nil
      }
    end
    fielding_stats = lines.filter_map { |line| fielding_stats_for_line(line) }
    chances = fielding_stats.sum { |stats| fielding_number(stats, "chances") }
    errors = fielding_stats.sum { |stats| fielding_number(stats, "errors") }
    direct_fielding_percentage = fielding_stats.filter_map do |stats|
      Float(stats["fielding"] || stats["fieldingPercentage"] || stats["fieldingPct"] || stats["fldgPct"], exception: false)
    end.first
    defensive_runs_saved = fielding_stats.filter_map { |stats| fielding_value(stats, %w[defensiveRunsSaved DRS drs]) }.sum
    outs_above_average = fielding_stats.filter_map { |stats| fielding_value(stats, %w[outsAboveAverage OAA oaa]) }.sum

    {
      positions: position_rows,
      fielding_percentage: direct_fielding_percentage || (chances.positive? ? (chances - errors).to_f / chances : nil),
      defensive_runs_saved: defensive_runs_saved.zero? ? nil : defensive_runs_saved,
      outs_above_average: outs_above_average.zero? ? nil : outs_above_average
    }
  rescue ActiveRecord::StatementInvalid
    { positions: [], fielding_percentage: nil }
  end

  def fielding_stats_for_line(line)
    line.raw_data.to_h.dig("stats", "fielding")
  end

  def fielding_number(stats, key)
    Integer(stats[key], exception: false) || 0
  end

  def fielding_value(stats, keys)
    keys.filter_map { |key| Float(stats[key], exception: false) }.first
  end

  def advanced_groups(category)
    return ADVANCED_BATTING_GROUPS if category == "batting"
    return ADVANCED_PITCHING_GROUPS if category == "pitching"

    []
  end

  def advanced_values(category, rows, career: false)
    return advanced_batting_values(rows, career: career) if category == "batting"

    advanced_pitching_values(rows, career: career)
  end

  def advanced_team_values(category, team_rows, season_rows)
    values = advanced_values(category, team_rows)
    return values unless category == "pitching"

    totals = advanced_values(category, season_rows)
    team_innings = season_additive_value(team_rows, %w[inningsPitched IP])
    season_innings = season_additive_value(season_rows, %w[inningsPitched IP])
    innings_share = if team_innings && season_innings
      safe_divide(
        innings_as_decimal(innings_to_outs(team_innings)),
        innings_as_decimal(innings_to_outs(season_innings))
      )
    end
    fip = team_fip(team_rows, season_rows)
    values[:fip] ||= fip
    values[:xfip] ||= totals[:xfip]
    values[:siera] ||= totals[:siera]
    values[:xera] ||= totals[:xera]
    values[:expected_woba_allowed] ||= totals[:expected_woba_allowed]
    values[:woba_allowed] ||= totals[:woba_allowed]
    values[:era_minus] ||= indexed_rate(values[:era], totals[:era], totals[:era_minus])
    values[:era_plus] ||= inverse_index(values[:era_minus])
    values[:fip_minus] ||= indexed_rate(values[:fip], totals[:fip], totals[:fip_minus])
    values[:xfip_minus] ||= indexed_rate(values[:xfip], totals[:xfip], totals[:xfip_minus])

    %i[war ra9_war wpa re24 runs_above_replacement runs_above_average pitching_runs shutdowns meltdowns].each do |key|
      values[key] ||= totals[key] && innings_share ? totals[key] * innings_share : nil
    end
    %i[wpa_per_li clutch leverage_index].each { |key| values[key] ||= totals[key] }
    values
  end

  def team_fip(team_rows, season_rows)
    innings = innings_as_decimal(innings_to_outs(season_additive_value(team_rows, %w[inningsPitched IP])))
    return if innings.nil? || innings.zero?

    home_runs = season_additive_value(team_rows, %w[homeRuns HR])
    walks = season_additive_value(team_rows, %w[baseOnBalls BB])
    hit_batters = season_additive_value(team_rows, %w[hitByPitch hitBatsmen HBP]) || 0
    strikeouts = season_additive_value(team_rows, %w[strikeOuts SO])
    return if [ home_runs, walks, strikeouts ].any?(&:nil?)

    total_innings = innings_as_decimal(innings_to_outs(season_additive_value(season_rows, %w[inningsPitched IP])))
    total_home_runs = season_additive_value(season_rows, %w[homeRuns HR])
    total_walks = season_additive_value(season_rows, %w[baseOnBalls BB])
    total_hit_batters = season_additive_value(season_rows, %w[hitByPitch hitBatsmen HBP]) || 0
    total_strikeouts = season_additive_value(season_rows, %w[strikeOuts SO])
    source_fip = advanced_rate(season_rows, %w[FIP fip], %w[inningsPitched IP], career: false)
    return if [ total_innings, total_home_runs, total_walks, total_strikeouts, source_fip ].any?(&:nil?)

    constant = source_fip - ((13 * total_home_runs + 3 * (total_walks + total_hit_batters) - 2 * total_strikeouts) / total_innings)
    (13 * home_runs + 3 * (walks + hit_batters) - 2 * strikeouts) / innings + constant
  end

  def indexed_rate(team_rate, total_rate, total_index)
    return if [ team_rate, total_rate, total_index ].any?(&:nil?) || total_rate.to_f.zero?

    team_rate.to_f / total_rate.to_f * total_index.to_f
  end

  def inverse_index(index)
    return if index.nil? || index.to_f.zero?

    10_000 / index.to_f
  end

  def advanced_batting_values(rows, career: false)
    plate_appearances = advanced_count(rows, %w[plateAppearances PA], career: career) ||
      derived_plate_appearances(rows, career: career)
    walks = advanced_count(rows, %w[baseOnBalls BB], career: career)
    strikeouts = advanced_count(rows, %w[strikeOuts SO], career: career)
    hits = advanced_count(rows, %w[hits H], career: career)
    home_runs = advanced_count(rows, %w[homeRuns HR], career: career)
    at_bats = advanced_count(rows, %w[atBats AB], career: career)
    sacrifice_flies = advanced_count(rows, %w[sacFlies SF], career: career)
    average = advanced_rate(rows, %w[avg AVG], %w[atBats AB], career: career)
    slugging = advanced_rate(rows, %w[slg SLG], %w[atBats AB], career: career)

    {
      bb_percentage: numeric_advanced_value(
        divide(walks, plate_appearances) || normalized_percentage_rate(advanced_rate(rows, [ "BB%", "walksPerPlateAppearance" ], %w[plateAppearances PA], career: career))
      ),
      k_percentage: numeric_advanced_value(
        divide(strikeouts, plate_appearances) || normalized_percentage_rate(advanced_rate(rows, [ "K%", "strikeoutsPerPlateAppearance" ], %w[plateAppearances PA], career: career))
      ),
      bb_per_k: numeric_advanced_value(
        divide(walks, strikeouts) || advanced_rate(rows, [ "BB/K", "walksPerStrikeout" ], %w[plateAppearances PA], career: career)
      ),
      iso: numeric_advanced_value(slugging && average ? slugging - average : advanced_rate(rows, %w[ISO iso], %w[plateAppearances PA], career: career)),
      babip: numeric_advanced_value(
        divide(hits && home_runs ? hits - home_runs : nil, at_bats && strikeouts && home_runs && sacrifice_flies ? at_bats - strikeouts - home_runs + sacrifice_flies : nil) ||
          advanced_rate(rows, %w[BABIP babip BAbip], %w[atBats AB], career: career)
      ),
      hr_per_fly_ball: numeric_advanced_value(advanced_home_run_per_fly_ball(rows, career: career)),
      woba: numeric_advanced_value(advanced_rate(rows, %w[wOBA woba], %w[plateAppearances PA], career: career)),
      wrc_plus: numeric_advanced_value(advanced_rate(rows, [ "wRC+", "wrc+", "wRCPlus", "wrcPlus" ], %w[plateAppearances PA], career: career)),
      ops_plus: numeric_advanced_value(advanced_rate(rows, [ "OPS+", "ops+", "OPSPlus", "opsPlus" ], %w[plateAppearances PA], career: career)),
      offensive_runs: numeric_advanced_value(advanced_count(rows, %w[Offense offensiveRuns], career: career)),
      baserunning_runs: numeric_advanced_value(advanced_count(rows, %w[BaseRunning baserunningRuns], career: career)),
      defensive_value: numeric_advanced_value(advanced_count(rows, %w[Defense defensiveValue], career: career)),
      war: numeric_advanced_value(advanced_count(rows, %w[WAR war], career: career)),
      ground_ball_percentage: numeric_advanced_value(advanced_batted_ball_rate(rows, [ "GB%", "groundBallPercentage" ], career: career)),
      fly_ball_percentage: numeric_advanced_value(advanced_batted_ball_rate(rows, [ "FB%", "flyBallPercentage" ], career: career)),
      line_drive_percentage: numeric_advanced_value(advanced_batted_ball_rate(rows, [ "LD%", "lineDrivePercentage" ], career: career)),
      pull_percentage: numeric_advanced_value(advanced_batted_ball_rate(rows, [ "Pull%", "pullPercentage" ], career: career)),
      center_percentage: numeric_advanced_value(advanced_batted_ball_rate(rows, [ "Cent%", "Center%", "centerPercentage" ], career: career)),
      opposite_field_percentage: numeric_advanced_value(advanced_batted_ball_rate(rows, [ "Oppo%", "oppositeFieldPercentage" ], career: career)),
      swing_percentage: numeric_advanced_value(advanced_plate_discipline_rate(rows, [ "Swing%", "swingPercentage" ], career: career)),
      chase_percentage: numeric_advanced_value(advanced_plate_discipline_rate(rows, [ "O-Swing%", "Chase%", "chasePercentage" ], career: career)),
      contact_percentage: numeric_advanced_value(advanced_plate_discipline_rate(rows, [ "Contact%", "contactPercentage" ], career: career)),
      zone_contact_percentage: numeric_advanced_value(advanced_plate_discipline_rate(rows, [ "Z-Contact%", "zoneContactPercentage" ], career: career)),
      swinging_strike_percentage: numeric_advanced_value(advanced_plate_discipline_rate(rows, [ "SwStr%", "swingingStrikePercentage" ], career: career))
    }
  end

  def advanced_pitching_values(rows, career: false)
    batters_faced = advanced_count(rows, %w[battersFaced TBF], career: career)
    strikeouts = advanced_count(rows, %w[strikeOuts SO], career: career)
    walks = advanced_count(rows, %w[baseOnBalls BB], career: career)
    hit_batters = advanced_count(rows, %w[hitByPitch hitBatsmen HBP], career: career)
    home_runs = advanced_count(rows, %w[homeRuns HR], career: career)
    k_percentage = divide(strikeouts, batters_faced) ||
      normalized_percentage_rate(advanced_rate(rows, [ "K%", "strikeoutPercentage" ], %w[battersFaced TBF], career: career))
    bb_percentage = divide(walks, batters_faced) ||
      normalized_percentage_rate(advanced_rate(rows, [ "BB%", "walkPercentage" ], %w[battersFaced TBF], career: career))
    innings = advanced_pitching_innings(rows)
    runs = advanced_count(rows, %w[runs R], career: career)
    earned_runs = advanced_count(rows, %w[earnedRuns ER], career: career)
    era_minus = advanced_rate(rows, [ "ERA-", "eraMinus" ], %w[inningsPitched IP], career: career, innings_weight: true)
    era = career ? pitching_era : season_pitching_era(rows)
    runs_per_nine = divide(runs && innings ? runs * 9 : nil, innings)
    earned_runs_per_nine = divide(earned_runs && innings ? earned_runs * 9 : nil, innings)

    values = {
      k_percentage: numeric_advanced_value(k_percentage),
      bb_percentage: numeric_advanced_value(bb_percentage),
      k_minus_bb_percentage: numeric_advanced_value(
        k_percentage && bb_percentage ? k_percentage - bb_percentage : advanced_rate(rows, [ "K-BB%" ], %w[battersFaced TBF], career: career)
      ),
      k_per_bb: numeric_advanced_value(
        divide(strikeouts, walks) || advanced_rate(rows, [ "K/BB", "strikeoutWalkRatio" ], %w[battersFaced TBF], career: career)
      ),
      hbp_percentage: numeric_advanced_value(divide(hit_batters, batters_faced)),
      hr_percentage: numeric_advanced_value(divide(home_runs, batters_faced)),
      babip: numeric_advanced_value(advanced_rate(rows, %w[BABIP babip BAbip], %w[battersFaced TBF], career: career)),
      lob_percentage: numeric_advanced_value(
        advanced_rate(rows, [ "LOB%", "leftOnBasePercentage" ], %w[inningsPitched IP], career: career, innings_weight: true)
      ),
      era: numeric_advanced_value(era),
      era_minus: numeric_advanced_value(era_minus),
      era_plus: numeric_advanced_value(
        advanced_rate(rows, [ "ERA+", "eraPlus" ], %w[inningsPitched IP], career: career, innings_weight: true) ||
          divide(10_000, era_minus)
      ),
      fip: numeric_advanced_value(advanced_rate(rows, %w[FIP fip], %w[inningsPitched IP], career: career, innings_weight: true)),
      fip_minus: numeric_advanced_value(advanced_rate(rows, [ "FIP-", "fipMinus" ], %w[inningsPitched IP], career: career, innings_weight: true)),
      xfip: numeric_advanced_value(advanced_rate(rows, %w[xFIP xfip], %w[inningsPitched IP], career: career, innings_weight: true)),
      xfip_minus: numeric_advanced_value(advanced_rate(rows, [ "xFIP-", "xfipMinus" ], %w[inningsPitched IP], career: career, innings_weight: true)),
      siera: numeric_advanced_value(advanced_rate(rows, %w[SIERA siera], %w[inningsPitched IP], career: career, innings_weight: true)),
      xera: numeric_advanced_value(advanced_rate(rows, %w[xERA xera], %w[inningsPitched IP], career: career, innings_weight: true)),
      ra9: numeric_advanced_value(runs_per_nine),
      runs_allowed_per_nine: numeric_advanced_value(runs_per_nine),
      earned_runs_allowed_per_nine: numeric_advanced_value(earned_runs_per_nine || era),
      expected_woba_allowed: numeric_advanced_value(advanced_rate(rows, %w[xwOBAAllowed xwOBA], %w[battersFaced TBF], career: career)),
      woba_allowed: numeric_advanced_value(advanced_rate(rows, %w[wOBAAllowed wOBA], %w[battersFaced TBF], career: career)),
      war: numeric_advanced_value(advanced_count(rows, %w[WAR war], career: career)),
      ra9_war: numeric_advanced_value(advanced_count(rows, [ "RA9-Wins", "RA9-WAR", "ra9War" ], career: career)),
      wpa: numeric_advanced_value(advanced_count(rows, %w[WPA wpa], career: career)),
      wpa_per_li: numeric_advanced_value(advanced_count(rows, [ "WPA/LI", "wpaPerLi" ], career: career)),
      re24: numeric_advanced_value(advanced_count(rows, %w[RE24 re24], career: career)),
      clutch: numeric_advanced_value(advanced_count(rows, %w[Clutch clutch], career: career)),
      runs_above_replacement: numeric_advanced_value(advanced_count(rows, %w[RAR rar], career: career)),
      runs_above_average: numeric_advanced_value(advanced_count(rows, %w[RAA raa], career: career)),
      pitching_runs: numeric_advanced_value(advanced_count(rows, [ "PitchingRuns", "pitchingRuns" ], career: career)),
      leverage_index: numeric_advanced_value(advanced_rate(rows, %w[pLI leverageIndex], %w[battersFaced TBF], career: career)),
      shutdowns: numeric_advanced_value(advanced_count(rows, %w[SD shutdowns], career: career)),
      meltdowns: numeric_advanced_value(advanced_count(rows, %w[MD meltdowns], career: career))
    }

    statcast_fallback = pitcher_statcast_value_fallback(rows, career: career)
    statcast_fallback.each { |key, value| values[key] = value if values[key].nil? && value.present? }
    calculated_fallback = calculated_pitching_run_prevention_values(values, rows, career: career)
    calculated_fallback.each { |key, value| values[key] = value if values[key].nil? && value.present? }
    values
  end

  def calculated_pitching_run_prevention_values(values, rows, career:)
    era_minus = values[:era_minus]
    era_plus = values[:era_plus]
    fallback = {}
    fallback[:era_minus] = (10_000.0 / era_plus.to_f).round(1) if era_minus.nil? && era_plus.to_f.positive?

    fip_values = rows.group_by(&:season).filter_map do |season, season_rows|
      totals = pitching_formula_totals(season_rows)
      next if totals.nil?

      constant = league_fip_constant(season)
      next if constant.nil?

      fip = ((13 * totals[:home_runs]) + (3 * (totals[:walks] + totals[:hit_batters])) - (2 * totals[:strikeouts])) / totals[:innings] + constant
      league_fip = league_pitching_rate(season, :fip)
      [ fip, league_fip ? (fip / league_fip * 100) : nil, totals[:innings] ]
    end
    if fip_values.any?
      if career
        innings = fip_values.sum { |_fip, _fip_minus, weight| weight }
        fallback[:fip] = (fip_values.sum { |fip, _fip_minus, weight| fip * weight } / innings).to_f.round(2) if innings.positive?
        fallback[:fip_minus] = (fip_values.filter_map { |_fip, fip_minus, weight| fip_minus && [ fip_minus, weight ] }.sum { |value, weight| value * weight } / innings).to_f.round(1) if innings.positive?
      else
        fallback[:fip] = fip_values.first[0].to_f.round(2)
        fallback[:fip_minus] = fip_values.first[1]&.to_f&.round(1)
      end
    end

    fallback
  end

  def pitching_formula_totals(rows)
    innings = rows.filter_map do |row|
      value = row.stat_type.name.in?(%w[inningsPitched IP]) ? row.value : nil
      innings_to_outs(value) if value
    end.sum
    return if innings.zero?

    values = {
      innings: innings_as_decimal(innings),
      home_runs: season_additive_value(rows, %w[homeRuns HR]),
      walks: season_additive_value(rows, %w[baseOnBalls BB]),
      hit_batters: season_additive_value(rows, %w[hitByPitch hitBatsmen HBP]) || 0,
      strikeouts: season_additive_value(rows, %w[strikeOuts SO])
    }
    return if [ values[:home_runs], values[:walks], values[:strikeouts] ].any?(&:nil?)

    values
  end

  def league_fip_constant(season)
    league_era = league_pitching_rate(season, :era)
    league_fip = league_fip_raw_rate(season)
    return if league_era.nil? || league_fip.nil?

    league_era - league_fip
  end

  def league_pitching_rate(season, metric)
    @league_pitching_rates ||= {}
    @league_pitching_rates[[ season, metric ]] ||= begin
      totals = league_pitching_totals(season)
      innings = totals[:innings]
      if innings.nil? || innings.zero?
        nil
      elsif metric == :era
        totals[:earned_runs].to_f * 9 / innings
      elsif metric == :fip
        league_fip_raw_rate(season).to_f + league_fip_constant(season).to_f
      else
        nil
      end
    end
  end

  def league_fip_raw_rate(season)
    totals = league_pitching_totals(season)
    innings = totals[:innings]
    return if innings.nil? || innings.zero?

    ((13 * totals[:home_runs]) + (3 * (totals[:walks] + totals[:hit_batters])) - (2 * totals[:strikeouts])) / innings
  end

  def league_pitching_totals(season)
    @league_pitching_totals ||= {}
    @league_pitching_totals[season] ||= begin
      games = GamePlayerPitchingLine.joins(:game).where(games: { official_date: Date.new(season, 1, 1)..Date.new(season, 12, 31) })
      lines = games.to_a
      if lines.any?
        outs = lines.sum { |line| line.outs_recorded.to_i }
        {
          innings: outs.positive? ? innings_as_decimal(outs) : nil,
          earned_runs: lines.sum { |line| line.earned_runs.to_i },
          home_runs: lines.sum { |line| line.home_runs.to_i },
          walks: lines.sum { |line| line.walks.to_i },
          hit_batters: lines.sum { |line| line.raw_data.to_h.dig("stats", "pitching", "hitByPitch").to_f },
          strikeouts: lines.sum { |line| line.strikeouts.to_i }
        }
      else
        league_pitching_totals_from_player_stats(season)
      end
    end
  end

  def league_pitching_totals_from_player_stats(season)
    names = %w[inningsPitched IP earnedRuns ER homeRuns HR baseOnBalls BB hitByPitch hitBatsmen HBP strikeOuts SO]
    stat_rows = PlayerSeasonStat.joins(:stat_type)
      .where(season: season, scope_type: "team", stat_types: { category: "pitching", name: names })
      .pluck("stat_types.name", :value)
    totals = Hash.new(0.0)
    stat_rows.each { |name, value| totals[name] += value.to_f }
    pick_total = lambda do |aliases|
      name = aliases.find { |alias_name| totals.key?(alias_name) }
      name ? totals[name] : 0.0
    end
    innings = stat_rows.filter_map { |name, value| innings_to_outs(value) if name.in?(%w[inningsPitched IP]) }.sum
    {
      innings: innings.zero? ? nil : innings_as_decimal(innings),
      earned_runs: pick_total.call(%w[earnedRuns ER]),
      home_runs: pick_total.call(%w[homeRuns HR]),
      walks: pick_total.call(%w[baseOnBalls BB]),
      hit_batters: pick_total.call(%w[hitByPitch hitBatsmen HBP]),
      strikeouts: pick_total.call(%w[strikeOuts SO])
    }
  end

  def pitcher_statcast_value_fallback(rows, career:)
    pitches = pitcher_statcast_rows(rows, career: career)
    return {} if pitches.empty?

    lines = GamePlayerPitchingLine.where(player: player, game_id: pitches.filter_map(&:game_id).uniq).to_a.index_by(&:game_id)
    wpa_rows = pitches.filter_map do |pitch|
      line = lines[pitch.game_id]
      delta = pitch.delta_home_win_exp&.to_f
      next if line.nil? || delta.nil?

      [ pitch, line.home? ? delta : -delta ]
    end
    game_wpa = wpa_rows.group_by { |pitch, _delta| pitch.game_id }
      .transform_values { |game_rows| game_rows.sum { |_pitch, delta| delta } }

    {
      wpa: rounded_statcast_value(wpa_rows.sum { |_pitch, delta| delta }),
      re24: rounded_statcast_value(pitches.filter_map { |pitch| pitch.delta_pitcher_run_exp&.to_f }.sum),
      shutdowns: game_wpa.count { |game_id, value| !lines[game_id].starter? && value >= 0.06 },
      meltdowns: game_wpa.count { |game_id, value| !lines[game_id].starter? && value <= -0.06 }
    }
  end

  def pitcher_statcast_rows(rows, career:)
    seasons = rows.filter_map(&:season).uniq.sort
    return [] if seasons.empty? || player.mlb_id.blank?

    team_ids = rows.filter_map(&:team_id).uniq
    cache_key = [ seasons, team_ids, career ]
    @pitcher_statcast_rows_cache ||= {}
    @pitcher_statcast_rows_cache[cache_key] ||= begin
      date_range = Date.new(seasons.first, 1, 1)..Date.new(seasons.last, 12, 31)
      pitches = PitchDatum.where(pitcher: player.mlb_id, game_date: date_range).to_a
      if team_ids.length != 1
        pitches
      else
        line_by_game_id = GamePlayerPitchingLine.where(player: player, game_id: pitches.filter_map(&:game_id).uniq)
          .pluck(:game_id, :team_id).to_h
        pitches.select { |pitch| line_by_game_id[pitch.game_id] == team_ids.first }
      end
    end
  end

  def rounded_statcast_value(value)
    value.to_f.round(3)
  end

  def advanced_pitching_innings(rows)
    outs = rows.group_by(&:season).values.filter_map do |season_rows|
      innings = season_additive_value(season_rows, %w[inningsPitched IP])
      innings_to_outs(innings) if innings
    end.sum
    return if outs.zero?

    innings_as_decimal(outs)
  end

  def advanced_batted_ball_rate(rows, aliases, career:)
    value = advanced_rate(rows, aliases, %w[ballsInPlay BIP], career: career)
    value || advanced_rate(rows, aliases, %w[plateAppearances PA], career: career)
  end

  def advanced_home_run_per_fly_ball(rows, career:)
    direct = advanced_rate(rows, %w[HR/FB hrPerFlyBall homeRunPerFlyBall], %w[ballsInPlay BIP], career: career)
    return direct if direct

    home_runs = advanced_count(rows, %w[homeRuns HR], career: career)
    batted_balls = advanced_count(rows, %w[ballsInPlay BIP], career: career)
    fly_ball_percentage = advanced_batted_ball_rate(rows, [ "FB%", "flyBallPercentage" ], career: career)
    fly_balls = batted_balls && fly_ball_percentage ? batted_balls * fly_ball_percentage : nil

    divide(home_runs, fly_balls)
  end

  def advanced_plate_discipline_rate(rows, aliases, career:)
    value = advanced_rate(rows, aliases, %w[numberOfPitches Pitches], career: career)
    value || advanced_rate(rows, aliases, %w[plateAppearances PA], career: career)
  end

  def derived_plate_appearances(rows, career:)
    components = [
      advanced_count(rows, %w[atBats AB], career: career),
      advanced_count(rows, %w[baseOnBalls BB], career: career),
      advanced_count(rows, %w[hitByPitch HBP], career: career),
      advanced_count(rows, %w[sacFlies SF], career: career),
      advanced_count(rows, %w[sacBunts SH], career: career)
    ]
    return if components.first.nil?

    components.compact.sum(0.to_d)
  end

  def advanced_count(rows, aliases, career:)
    return season_additive_value(rows, aliases) unless career

    rows.group_by(&:season).values.filter_map { |season_rows| season_additive_value(season_rows, aliases) }.presence&.sum(0.to_d)
  end

  def advanced_rate(rows, aliases, weight_aliases, career:, innings_weight: false)
    return best_stat_row_from(rows, aliases)&.value unless career

    weighted_values = rows.group_by(&:season).values.filter_map do |season_rows|
      value = best_stat_row_from(season_rows, aliases)&.value
      weight = season_additive_value(season_rows, weight_aliases)
      weight ||= derived_plate_appearances(season_rows, career: false) if (weight_aliases & %w[plateAppearances PA]).any?
      next if value.nil? || weight.nil? || !weight.positive?

      normalized_weight = innings_weight ? innings_as_decimal(innings_to_outs(weight)) : weight
      [ value, normalized_weight ]
    end
    return if weighted_values.empty?

    divide(
      weighted_values.sum(0.to_d) { |value, weight| value * weight },
      weighted_values.sum(0.to_d) { |_value, weight| weight }
    )
  end

  def numeric_advanced_value(value)
    value.nil? ? nil : value.to_f
  end

  def normalized_percentage_rate(value)
    return if value.nil?

    value > 1 ? value / 100 : value
  end

  def career_columns(category)
    available_keys = serialized_career_stats(category).pluck(:key)

    PlayerSeasonStatsLeaderboardQuery::COLUMN_DEFINITIONS_BY_CATEGORY.fetch(category).filter_map do |definition|
      next unless available_keys.include?(definition.fetch(:key))

      { key: definition.fetch(:key), label: definition.fetch(:label) }
    end
  end

  def serialized_career_seasons(category)
    career_rows_by_season(category).sort.map do |season, rows|
      team_rows = team_rows_for_season(rows)
      {
        season: season,
        teams: rows.filter_map(&:team).uniq(&:id).map { |team| serialize_team(team) },
        stats: serialized_stats_for_season(category, rows),
        team_rows: team_rows.map { |team, team_stats| { team: serialize_team(team), stats: serialized_stats_for_season(category, team_stats) } },
        total_stats: serialized_stats_for_season(category, rows)
      }
    end
  end

  def team_rows_for_season(rows)
    rows
      .select { |row| row.scope_type == "team" && row.team.present? }
      .group_by(&:team)
      .sort_by { |team, _| [ team.abbreviation.to_s, team.id ] }
  end

  def serialized_stats_for_season(category, rows)
    PlayerSeasonStatsLeaderboardQuery::COLUMN_DEFINITIONS_BY_CATEGORY.fetch(category).filter_map do |definition|
      value = season_stat_value(category, definition, rows)
      next if value.nil?

      {
        key: definition.fetch(:key),
        label: definition.fetch(:label),
        value: format_career_value(category, definition.fetch(:key), value)
      }
    end
  end

  def season_stat_value(category, definition, rows)
    key = definition.fetch(:key)
    aliases = Array(definition.fetch(:aliases))

    if category == "pitching" && key == "inningsPitched"
      innings = season_additive_value(rows, aliases)
      return innings.nil? ? nil : format_innings(innings_to_outs(innings))
    end
    return season_batting_average(rows) if category == "batting" && key == "avg"
    return season_batting_obp(rows) if category == "batting" && key == "obp"
    return season_batting_slugging(rows) if category == "batting" && key == "slg"
    return season_batting_ops(rows) if category == "batting" && key == "ops"
    return season_pitching_era(rows) if category == "pitching" && key == "ERA"
    return season_pitching_whip(rows) if category == "pitching" && key == "whip"
    return season_pitching_average(rows) if category == "pitching" && key == "avg"

    season_additive_value(rows, aliases)
  end

  def season_batting_average(rows)
    season_weighted_rate(rows, %w[avg AVG], %w[atBats AB]) || divide(
      season_additive_value(rows, %w[hits H]),
      season_additive_value(rows, %w[atBats AB])
    )
  end

  def season_batting_slugging(rows)
    hits = season_additive_value(rows, %w[hits H])
    at_bats = season_additive_value(rows, %w[atBats AB])
    doubles = season_additive_value(rows, %w[doubles 2B]) || 0.to_d
    triples = season_additive_value(rows, %w[triples 3B]) || 0.to_d
    home_runs = season_additive_value(rows, %w[homeRuns HR]) || 0.to_d
    return season_weighted_rate(rows, %w[slg SLG], %w[atBats AB]) if hits.nil? || at_bats.nil?

    divide(hits + doubles + (triples * 2) + (home_runs * 3), at_bats)
  end

  def season_batting_obp(rows)
    hits = season_additive_value(rows, %w[hits H])
    walks = season_additive_value(rows, %w[baseOnBalls BB])
    hit_by_pitch = season_additive_value(rows, %w[hitByPitch HBP])
    sacrifice_flies = season_additive_value(rows, %w[sacFlies SF])
    at_bats = season_additive_value(rows, %w[atBats AB])
    components = [ hits, walks, hit_by_pitch, sacrifice_flies, at_bats ]
    return season_weighted_rate(rows, %w[obp OBP], %w[atBats AB]) if components.any?(&:nil?)

    divide(hits + walks + hit_by_pitch, at_bats + walks + hit_by_pitch + sacrifice_flies)
  end

  def season_batting_ops(rows)
    obp = season_batting_obp(rows)
    slg = season_batting_slugging(rows)
    return season_weighted_rate(rows, %w[ops OPS], %w[atBats AB]) if obp.nil? || slg.nil?

    obp + slg
  end

  def season_pitching_era(rows)
    earned_runs = season_additive_value(rows, %w[ER earnedRuns])
    innings_value = season_additive_value(rows, %w[inningsPitched IP])
    innings = innings_as_decimal(innings_to_outs(innings_value)) if innings_value.present?
    return season_weighted_rate(rows, %w[ERA era], %w[inningsPitched IP], innings_weight: true) if earned_runs.nil?

    divide(earned_runs * 9, innings)
  end

  def season_pitching_whip(rows)
    hits = season_additive_value(rows, %w[hits H])
    walks = season_additive_value(rows, %w[baseOnBalls BB])
    innings_value = season_additive_value(rows, %w[inningsPitched IP])
    innings = innings_as_decimal(innings_to_outs(innings_value)) if innings_value.present?
    if hits.nil? || walks.nil?
      return season_weighted_rate(rows, %w[whip WHIP], %w[inningsPitched IP], innings_weight: true)
    end

    divide(hits + walks, innings)
  end

  def season_pitching_average(rows)
    hits = season_additive_value(rows, %w[hits H])
    at_bats = season_additive_value(rows, %w[atBats AB])
    return season_weighted_rate(rows, %w[avg AVG], %w[inningsPitched IP], innings_weight: true) if hits.nil? || at_bats.nil?

    divide(hits, at_bats)
  end

  def season_weighted_rate(rows, rate_aliases, weight_aliases, innings_weight: false)
    rate_rows = rows_for_preferred_alias(rows, rate_aliases)
    return if rate_rows.empty?

    combined = rate_rows.select { |row| row.scope_type == "combined" }.max_by(&:updated_at)
    return combined.value if combined.present?

    weighted_values = rate_rows.filter_map do |rate_row|
      matching_rows = rows.select do |row|
        row.scope_type == rate_row.scope_type && row.scope_key == rate_row.scope_key && row.team_id == rate_row.team_id
      end
      weight = season_additive_value(matching_rows, weight_aliases)
      next if weight.nil?

      numeric_weight = innings_weight ? innings_as_decimal(innings_to_outs(weight)) : weight
      next unless numeric_weight&.positive?

      [ rate_row.value, numeric_weight ]
    end
    return best_stat_row_from(rows, rate_aliases)&.value if weighted_values.empty?

    numerator = weighted_values.sum(0.to_d) { |value, weight| value * weight }
    denominator = weighted_values.sum(0.to_d) { |_value, weight| weight }
    divide(numerator, denominator)
  end

  def career_category
    available_categories = all_season_rows.map { |row| row.stat_type.category }.uniq & SEASON_CATEGORIES
    available_categories.include?(preferred_category) ? preferred_category : available_categories.first || preferred_category
  end

  def serialized_career_stats(category)
    definitions = PlayerSeasonStatsLeaderboardQuery::COLUMN_DEFINITIONS_BY_CATEGORY.fetch(category)

    definitions.filter_map do |definition|
      value = career_stat_value(category, definition)
      next if value.nil?

      {
        key: definition.fetch(:key),
        label: definition.fetch(:label),
        value: format_career_value(category, definition.fetch(:key), value)
      }
    end
  end

  def serialized_comparison_stats(category, rows, career:)
    values = advanced_values(category, rows, career: career)

    COMPARISON_RATE_METRICS.filter_map do |metric|
      value = values[metric.fetch(:key)]
      next if value.nil?

      {
        key: metric.fetch(:key).to_s,
        label: metric.fetch(:label),
        value: value
      }
    end
  end

  def career_stat_value(category, definition)
    key = definition.fetch(:key)
    aliases = Array(definition.fetch(:aliases))

    return format_innings(career_innings_outs) if category == "pitching" && key == "inningsPitched"
    return batting_average if category == "batting" && key == "avg"
    return batting_obp if category == "batting" && key == "obp"
    return batting_slugging if category == "batting" && key == "slg"
    return batting_ops if category == "batting" && key == "ops"
    return pitching_era if category == "pitching" && key == "ERA"
    return pitching_whip if category == "pitching" && key == "whip"
    return pitching_average if category == "pitching" && key == "avg"

    additive_career_value(category, aliases)
  end

  def batting_average
    divide(
      additive_career_value("batting", %w[hits H]),
      additive_career_value("batting", %w[atBats AB])
    ) || weighted_career_rate("batting", %w[avg AVG], %w[atBats AB])
  end

  def batting_slugging
    hits = additive_career_value("batting", %w[hits H])
    at_bats = additive_career_value("batting", %w[atBats AB])
    doubles = additive_career_value("batting", %w[doubles 2B]) || 0.to_d
    triples = additive_career_value("batting", %w[triples 3B]) || 0.to_d
    home_runs = additive_career_value("batting", %w[homeRuns HR]) || 0.to_d
    return weighted_career_rate("batting", %w[slg SLG], %w[atBats AB]) if hits.nil? || at_bats.nil?

    total_bases = hits + doubles + (triples * 2) + (home_runs * 3)
    divide(total_bases, at_bats)
  end

  def batting_obp
    hits = additive_career_value("batting", %w[hits H])
    walks = additive_career_value("batting", %w[baseOnBalls BB])
    hit_by_pitch = additive_career_value("batting", %w[hitByPitch HBP])
    sacrifice_flies = additive_career_value("batting", %w[sacFlies SF])
    at_bats = additive_career_value("batting", %w[atBats AB])
    components = [ hits, walks, hit_by_pitch, sacrifice_flies, at_bats ]
    return weighted_career_rate("batting", %w[obp OBP], %w[atBats AB]) if components.any?(&:nil?)

    divide(hits + walks + hit_by_pitch, at_bats + walks + hit_by_pitch + sacrifice_flies)
  end

  def batting_ops
    obp = batting_obp
    slg = batting_slugging
    return weighted_career_rate("batting", %w[ops OPS], %w[atBats AB]) if obp.nil? || slg.nil?

    obp + slg
  end

  def pitching_era
    earned_runs = additive_career_value("pitching", %w[ER earnedRuns])
    innings = innings_as_decimal(career_innings_outs)
    return weighted_career_rate("pitching", %w[ERA era], %w[inningsPitched IP], innings_weight: true) if earned_runs.nil?

    divide(earned_runs * 9, innings)
  end

  def pitching_whip
    hits = additive_career_value("pitching", %w[hits H])
    walks = additive_career_value("pitching", %w[baseOnBalls BB])
    innings = innings_as_decimal(career_innings_outs)
    if hits.nil? || walks.nil?
      return weighted_career_rate("pitching", %w[whip WHIP], %w[inningsPitched IP], innings_weight: true)
    end

    divide(hits + walks, innings)
  end

  def pitching_average
    hits = additive_career_value("pitching", %w[hits H])
    at_bats = additive_career_value("pitching", %w[atBats AB])
    return weighted_career_rate("pitching", %w[avg AVG], %w[inningsPitched IP], innings_weight: true) if hits.nil? || at_bats.nil?

    divide(hits, at_bats)
  end

  def additive_career_value(category, aliases)
    values = career_rows_by_season(category).values.filter_map do |rows|
      season_additive_value(rows, aliases)
    end
    return nil if values.empty?

    values.sum(0.to_d)
  end

  def season_additive_value(rows, aliases)
    candidates = rows_for_preferred_alias(rows, aliases)
    return if candidates.empty?

    combined = candidates.select { |row| row.scope_type == "combined" }.max_by(&:updated_at)
    return combined.value if combined.present?

    team_rows = candidates.select { |row| row.scope_type == "team" }
    return team_rows.sum(0.to_d, &:value) if team_rows.any?

    candidates.min_by { |row| [ scope_priority(row), -row.updated_at.to_f ] }.value
  end

  def weighted_career_rate(category, rate_aliases, weight_aliases, innings_weight: false)
    weighted_values = career_rows_by_season(category).values.filter_map do |rows|
      rate_row = best_stat_row_from(rows, rate_aliases)
      weight = season_additive_value(rows, weight_aliases)
      next if rate_row.nil? || weight.nil?

      numeric_weight = innings_weight ? innings_as_decimal(innings_to_outs(weight)) : weight
      next unless numeric_weight&.positive?

      [ rate_row.value, numeric_weight ]
    end
    return nil if weighted_values.empty?

    numerator = weighted_values.sum(0.to_d) { |value, weight| value * weight }
    denominator = weighted_values.sum(0.to_d) { |_value, weight| weight }
    divide(numerator, denominator)
  end

  def career_innings_outs
    values = career_rows_by_season("pitching").values.filter_map do |rows|
      season_additive_value(rows, %w[inningsPitched IP])
    end
    return if values.empty?

    values.sum { |value| innings_to_outs(value) }
  end

  def innings_to_outs(value)
    return if value.nil?

    whole_innings = value.floor
    partial_outs = ((value - whole_innings) * 10).round.to_i.clamp(0, 2)
    (whole_innings * 3) + partial_outs
  end

  def innings_as_decimal(outs)
    return if outs.nil? || outs.zero?

    outs.to_d / 3
  end

  def format_innings(outs)
    return if outs.nil?

    "#{outs / 3}.#{outs % 3}"
  end

  def divide(numerator, denominator)
    return if numerator.nil? || denominator.nil? || denominator.zero?

    numerator.to_d / denominator.to_d
  end

  def format_career_value(category, key, value)
    return value if value.is_a?(String)
    return format("%.3f", value) if category == "batting" && BATTING_RATE_KEYS.include?(key)
    return format("%.2f", value) if category == "pitching" && %w[ERA whip].include?(key)
    return format("%.3f", value) if category == "pitching" && PITCHING_RATE_KEYS.include?(key)

    decimal = value.to_d
    decimal.frac.zero? ? decimal.to_i.to_s : decimal.to_s("F")
  end

  def latest_season
    @latest_season ||= player.player_season_stats.maximum(:season)
  end

  def season_rows
    @season_rows ||= all_season_rows.select { |row| row.season == latest_season }
  end

  def all_season_rows
    @all_season_rows ||= begin
      stored_rows = player.player_season_stats.includes(:stat_type, :team).to_a
      normalized_rows = normalize_mislabeled_team_totals(stored_rows)
      normalized_rows = normalize_duplicate_team_scopes(normalized_rows)
      corrected_rows = correct_mismatched_team_rows(normalized_rows)
      corrected_rows + derived_game_stat_rows(corrected_rows)
    end
  end

  # Historical MLB responses can contain the same team split more than once
  # under different abbreviations while retaining the same team id. Treat
  # those rows as one split; otherwise team_rows_for_season groups them by the
  # Team record and season_additive_value sums the duplicate values.
  def normalize_duplicate_team_scopes(stored_rows)
    canonical_scopes = stored_rows
      .select { |row| row.scope_type == "team" && row.team_id.present? }
      .group_by { |row| [ row.stat_type.category, row.season, row.team_id ] }
      .filter_map do |(_category, _season, _team_id), rows|
        scopes = rows.group_by(&:scope_key)
        next if scopes.one? || !duplicate_scope_values?(scopes)

        canonical_scope = rows.first.team&.abbreviation.to_s.presence
        canonical_scope ||= scopes.keys.compact.min_by { |scope| scope.to_s }
        [ rows.first.stat_type.category, rows.first.season, rows.first.team_id, canonical_scope ]
      end.to_h { |category, season, team_id, scope| [[ category, season, team_id ], scope] }

    stored_rows.reject do |row|
      canonical_scope = canonical_scopes[[ row.stat_type.category, row.season, row.team_id ]]
      canonical_scope.present? && row.scope_key != canonical_scope
    end
  end

  def duplicate_scope_values?(scopes)
    scope_values = scopes.values.map do |scope_rows|
      scope_rows.to_h { |row| [ row.stat_type.name, row.value ] }
    end
    shared_stat_names = scope_values.map(&:keys).reduce(&:&)
    shared_stat_names.present? && shared_stat_names.all? do |stat_name|
      scope_values.map { |values| values.fetch(stat_name) }.uniq.one?
    end
  end

  def analytics_payload
    {
      recent_pitch_indicators: recent_pitch_indicators,
      batted_ball_profile: batted_ball_profile,
      pitch_arsenal: pitch_arsenal,
      contextual_benchmarks: PlayerBenchmarkSnapshotQuery.new(
        player: player,
        start_date: analysis_range.start_date,
        end_date: analysis_range.end_date
      ).result,
      trend_events: PlayerTrendEventQuery.new(
        player: player,
        start_date: analysis_range.start_date,
        end_date: analysis_range.end_date
      ).result,
      analysis: PlayerTrendQuery.new(player: player, analysis_range: analysis_range).result
    }
  end

  def batted_ball_profile
    points = PitchDatum
      .where(batter: player.mlb_id, game_date: analysis_range.start_date..analysis_range.end_date)
      .where.not(hc_x: nil, hc_y: nil)
      .select(:id, :game_date, :hc_x, :hc_y, :events, :bb_type, :launch_speed, :launch_angle, :hit_distance_sc, :description)
      .order(:game_date, :id)
      .to_a
      .select { |row| DailyAnalyticsCalculator.batted_ball?(row) }
      .map { |row| serialize_batted_ball_point(row) }

    {
      available: points.any?,
      contact_count: points.length,
      spray_points: points,
      hit_points: points.select { |point| HIT_EVENTS.include?(point[:event]) },
      pitcher_metrics: pitcher_batted_ball_metrics
    }
  end

  def pitcher_batted_ball_metrics
    rows = PitchDatum
      .where(pitcher: player.mlb_id)
      .where.not(game_date: nil)
      .select(:game_date, :bb_type, :events, :launch_speed, :launch_angle, :launch_speed_angle, :hc_x, :stand, :description)
      .to_a
      .select { |row| DailyAnalyticsCalculator.batted_ball?(row) }

    summary = pitcher_batted_ball_metric_summary(rows)
    summary[:seasons] = rows.group_by { |row| row.game_date.year }
      .sort_by { |season, _| -season }
      .map { |season, season_rows| pitcher_batted_ball_metric_summary(season_rows).merge(season: season) }
    summary
  end

  def pitch_arsenal
    rows = PitchDatum
      .where(pitcher: player.mlb_id, game_date: analysis_range.start_date..analysis_range.end_date)
      .where.not(pitch_type: [ nil, "" ])
      .to_a
    total = rows.length

    {
      available: rows.any?,
      pitches: rows.group_by(&:pitch_type).map do |pitch_type, grouped|
        batted_balls = grouped.select { |row| DailyAnalyticsCalculator.batted_ball?(row) }
        swings = grouped.count { |row| DailyAnalyticsCalculator.swing?(row) }
        chase_opportunities = grouped.count { |row| row.zone.present? && !row.zone.to_i.between?(1, 9) }
        chases = grouped.count { |row| chase_opportunities.positive? && DailyAnalyticsCalculator.swing?(row) && row.zone.present? && !row.zone.to_i.between?(1, 9) }
        spin_efficiencies = grouped.filter_map { |row| raw_pitch_value(row, "active_spin", "spin_efficiency") }
        run_values = grouped.filter_map { |row| row.delta_run_exp&.to_f }

        {
          pitch_type: pitch_type,
          pitch_name: grouped.filter_map(&:pitch_name).first || pitch_type,
          usage_percentage: percentage(grouped.length, total),
          pitch_count: grouped.length,
          average_velocity: average(grouped.filter_map { |row| row.release_speed&.to_f }),
          maximum_velocity: grouped.filter_map { |row| row.release_speed&.to_f }.max&.round(1),
          spin_rate: average(grouped.filter_map { |row| row.release_spin_rate&.to_f }),
          active_spin: average(spin_efficiencies),
          vertical_movement: average(grouped.filter_map { |row| row.pfx_z&.to_f * 12 }),
          horizontal_movement: average(grouped.filter_map { |row| row.pfx_x&.to_f * 12 }),
          zone_percentage: percentage(grouped.count { |row| row.zone.to_i.between?(1, 9) }, grouped.length),
          chase_percentage: percentage(chases, chase_opportunities),
          whiff_percentage: percentage(grouped.count { |row| DailyAnalyticsCalculator.whiff?(row) }, swings),
          hard_hit_percentage: percentage(batted_balls.count { |row| row.launch_speed.to_f >= 95.0 }, batted_balls.length),
          run_value: run_values.any? ? run_values.sum.round(2) : nil
        }
      end.sort_by { |pitch| -pitch[:pitch_count] }
    }
  end

  def raw_pitch_value(row, *keys)
    keys.filter_map { |key| row.raw_data.to_h[key] || row.raw_data.to_h[key.to_sym] }.first&.to_f
  end

  def pitcher_batted_ball_metric_summary(rows)
    types = rows.group_by { |row| pitcher_batted_ball_type(row) }
    fly_balls = Array(types[:fly_ball]) + Array(types[:infield_fly])
    directional_rows = rows.select { |row| row.hc_x.present? && %w[L R].include?(row.stand) }
    pulled_balls = directional_rows.count { |row| pulled_batted_ball?(row) }

    {
      available: rows.any?,
      batted_ball_count: rows.length,
      ground_ball_percentage: percentage(Array(types[:ground_ball]).length, rows.length),
      fly_ball_percentage: percentage(fly_balls.length, rows.length),
      ground_ball_to_fly_ball_ratio: ratio(Array(types[:ground_ball]).length, fly_balls.length),
      line_drive_percentage: percentage(Array(types[:line_drive]).length, rows.length),
      infield_fly_percentage: percentage(Array(types[:infield_fly]).length, fly_balls.length),
      pull_percentage: percentage(pulled_balls, directional_rows.length),
      hard_hit_percentage: percentage(rows.count { |row| row.launch_speed.to_f >= 95.0 }, rows.length),
      barrel_percentage: percentage(rows.count { |row| row.launch_speed_angle.to_i == GameBattedBallAnalysis::BARREL_CLASSIFICATION }, rows.length),
      home_run_per_fly_ball: percentage(rows.count { |row| row.events.to_s.downcase == "home_run" }, fly_balls.length),
      average_launch_angle: average(rows.filter_map { |row| row.launch_angle&.to_f })
    }
  end

  def pitcher_batted_ball_type(row)
    normalized = row.bb_type.to_s.downcase.tr(" -", "_")
    return :ground_ball if %w[ground_ball groundball ground].include?(normalized)
    return :line_drive if %w[line_drive linedrive line].include?(normalized)
    return :infield_fly if %w[popup pop_up infield_fly].include?(normalized)
    return :fly_ball if %w[fly_ball flyball fly].include?(normalized)

    return :unknown if row.launch_angle.blank?
    return :ground_ball if row.launch_angle < 10
    return :line_drive if row.launch_angle < 25

    :fly_ball
  end

  def pulled_batted_ball?(row)
    (row.stand == "R" && row.hc_x < 92) || (row.stand == "L" && row.hc_x > 158)
  end

  def serialize_batted_ball_point(row)
    {
      x: rounded(row.hc_x),
      y: rounded(row.hc_y),
      event: row.events,
      batted_ball_type: row.bb_type,
      exit_velocity: rounded(row.launch_speed),
      launch_angle: rounded(row.launch_angle),
      hit_distance: rounded(row.hit_distance_sc),
      game_date: row.game_date
    }
  end

  def normalize_mislabeled_team_totals(stored_rows)
    mislabeled_keys = %w[batting pitching].flat_map do |category|
      rows_by_scope = stored_rows
        .select { |row| row.stat_type.category == category && row.scope_type == "team" && row.team.present? }
        .group_by { |row| [ row.season, row.team_id ] }
      line_groups = game_line_groups(category, stored_rows)

      rows_by_scope.filter_map do |(season, team_id), rows|
        team = rows.first.team
        team_game_count = line_groups.fetch([ season, team ], []).map(&:game_id).uniq.length
        season_game_count = line_groups
          .select { |(line_season, _team), _lines| line_season == season }
          .values
          .flatten
          .map(&:game_id)
          .uniq
          .length
        source_game_count = source_game_count(category, rows)

        [ category, season, team_id ] if team_game_count.zero? && season_game_count > team_game_count && source_game_count == season_game_count
      end
    end

    stored_rows.map do |row|
      key = [ row.stat_type.category, row.season, row.team_id ]
      next row unless mislabeled_keys.include?(key)

      row.dup.tap do |total_row|
        total_row.team = nil
        total_row.scope_type = "combined"
        total_row.scope_key = "TOT"
      end
    end
  end

  def source_game_count(category, rows)
    aliases = category == "batting" ? %w[gamesPlayed G] : %w[G gamesPitched gamesPlayed]
    best_stat_row_from(rows, aliases)&.value&.to_i
  end

  def derived_game_stat_rows(stored_rows)
    existing_team_keys = stored_rows
      .select { |row| row.scope_type == "team" && row.team_id.present? }
      .map { |row| [ row.stat_type.category, row.season, row.team_id ] }
      .uniq

    derived_rows = []
    game_line_groups("batting", stored_rows).each do |(season, team), lines|
      next if existing_team_keys.include?([ "batting", season, team.id ])

      derived_rows.concat(build_derived_stat_rows("batting", season, team, batting_values_from_game_lines(lines)))
    end
    game_line_groups("pitching", stored_rows).each do |(season, team), lines|
      next if existing_team_keys.include?([ "pitching", season, team.id ])

      derived_rows.concat(build_derived_stat_rows("pitching", season, team, pitching_values_from_game_lines(lines)))
    end
    derived_rows
  end

  def correct_mismatched_team_rows(stored_rows)
    replacements = %w[batting pitching].flat_map do |category|
      game_line_groups(category, stored_rows).filter_map do |(season, team), lines|
        rows = stored_rows.select do |row|
          row.stat_type.category == category && row.season == season && row.scope_type == "team" && row.team_id == team.id
        end
        next if rows.empty?

        imported_game_count = source_game_count(category, rows)
        actual_game_count = lines.map(&:game_id).uniq.length
        next if imported_game_count.blank? || actual_game_count.zero? || imported_game_count == actual_game_count

        derived_rows = build_derived_stat_rows(
          category,
          season,
          team,
          category == "batting" ? batting_values_from_game_lines(lines) : pitching_values_from_game_lines(lines)
        ).reject do |row|
          AUTHORITATIVE_RATE_STAT_NAMES.fetch(category).include?(row.stat_type.name)
        end

        [ [ category, season, team.id ], derived_rows ]
      end
    end.to_h

    replacements_by_key = replacements
    replaced_stat_names_by_key = replacements_by_key.transform_values do |rows|
      rows.map { |row| row.stat_type.name }
    end
    stored_rows.reject do |row|
      key = [ row.stat_type.category, row.season, row.team_id ]
      Array(replaced_stat_names_by_key[key]).include?(row.stat_type.name)
    end + replacements_by_key.values.flatten
  end

  def game_line_groups(category, stored_rows)
    @game_line_groups ||= {}
    return @game_line_groups[category] if @game_line_groups.key?(category)

    seasons = stored_rows
      .select { |row| row.stat_type.category == category }
      .map(&:season)
      .compact
      .uniq
    return @game_line_groups[category] = {} if seasons.empty?

    relation = category == "batting" ? GamePlayerBattingLine : GamePlayerPitchingLine
    table_name = relation.table_name
    @game_line_groups[category] = relation
      .joins(:game)
      .where(player_id: player.id, games: { status: "final", official_date: Date.new(seasons.min, 1, 1)..Date.new(seasons.max, 12, 31) })
      .preload(:team)
      .select("#{table_name}.*, games.official_date AS profile_official_date")
      .to_a
      .select { |line| seasons.include?(line.profile_official_date.year) }
      .group_by { |line| [ line.profile_official_date.year, line.team ] }
  end

  def fallback_seasons(category, stored_rows)
    @fallback_seasons ||= {}
    return @fallback_seasons[category] if @fallback_seasons.key?(category)

    stat_team_ids_by_season = stored_rows
      .select { |row| row.stat_type.category == category && row.scope_type == "team" && row.team_id.present? }
      .group_by(&:season)
      .transform_values { |rows| rows.map(&:team_id).uniq }
    membership_team_ids_by_season = memberships.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |membership, seasons|
      first_season = membership.starts_on.year
      last_season = (membership.ends_on || on).year
      (first_season..last_season).each { |season| seasons[season] << membership.team_id }
    end

    @fallback_seasons[category] = membership_team_ids_by_season.filter_map do |season, team_ids|
      season if team_ids.uniq.length > stat_team_ids_by_season.fetch(season, []).length
    end
  end

  def build_derived_stat_rows(category, season, team, values)
    stat_types = StatType.cached_where(category: category, name: values.keys).index_by(&:name)
    values.filter_map do |name, value|
      stat_type = stat_types[name.to_s]
      next if stat_type.nil? || value.nil?

      PlayerSeasonStat.new(
        player: player,
        team: team,
        stat_type: stat_type,
        season: season,
        value: value,
        scope_type: "team",
        scope_key: team.abbreviation,
        updated_at: Time.current
      )
    end
  end

  def batting_values_from_game_lines(lines)
    totals = sum_game_line_fields(lines, %i[plate_appearances at_bats runs hits doubles triples home_runs runs_batted_in walks strikeouts stolen_bases caught_stealing])
    total_bases = totals[:hits] + totals[:doubles] + (2 * totals[:triples]) + (3 * totals[:home_runs])
    average = safe_divide(totals[:hits], totals[:at_bats])
    obp = safe_divide(totals[:hits] + totals[:walks], totals[:at_bats] + totals[:walks])
    slugging = safe_divide(total_bases, totals[:at_bats])

    totals.merge(
      gamesPlayed: lines.map(&:game_id).uniq.length,
      atBats: totals[:at_bats],
      runs: totals[:runs],
      hits: totals[:hits],
      doubles: totals[:doubles],
      triples: totals[:triples],
      homeRuns: totals[:home_runs],
      rbi: totals[:runs_batted_in],
      baseOnBalls: totals[:walks],
      strikeOuts: totals[:strikeouts],
      stolenBases: totals[:stolen_bases],
      caughtStealing: totals[:caught_stealing],
      avg: average,
      obp: obp,
      slg: slugging,
      ops: average && obp && slugging ? obp + slugging : nil
    ).compact
  end

  def pitching_values_from_game_lines(lines)
    totals = sum_game_line_fields(lines, %i[outs_recorded batters_faced hits runs earned_runs home_runs walks strikeouts saves blown_saves])
    hit_batters = sum_raw_pitching_stat(lines, "hitByPitch")
    at_bats = sum_raw_pitching_stat(lines, "atBats")
    sacrifice_flies = sum_raw_pitching_stat(lines, "sacFlies")
    outs = totals[:outs_recorded]
    innings = outs / 3 + (outs % 3) / 10.0
    earned_run_average = safe_divide(totals[:earned_runs] * 9, outs / 3.0)
    whip = safe_divide((totals[:hits] + totals[:walks]) * 3, outs)
    batters_faced = totals[:batters_faced]
    strikeout_rate = safe_divide(totals[:strikeouts], batters_faced)
    walk_rate = safe_divide(totals[:walks], batters_faced)
    babip = safe_divide(totals[:hits] - totals[:home_runs], at_bats - totals[:strikeouts] - totals[:home_runs] + sacrifice_flies)
    lob_percentage = safe_divide(
      totals[:hits] + totals[:walks] + hit_batters - totals[:runs],
      totals[:hits] + totals[:walks] + hit_batters - (1.4 * totals[:home_runs])
    )

    totals.merge(
      W: lines.count { |line| line.decision.to_s.include?("(W") },
      L: lines.count { |line| line.decision.to_s.include?("(L") },
      G: lines.map(&:game_id).uniq.length,
      GS: lines.count(&:starter),
      SV: totals[:saves],
      SVO: totals[:saves] + totals[:blown_saves],
      inningsPitched: innings,
      IP: innings,
      H: totals[:hits],
      R: totals[:runs],
      ER: totals[:earned_runs],
      homeRuns: totals[:home_runs],
      HR: totals[:home_runs],
      BB: totals[:walks],
      baseOnBalls: totals[:walks],
      SO: totals[:strikeouts],
      strikeOuts: totals[:strikeouts],
      TBF: batters_faced,
      battersFaced: batters_faced,
      HBP: hit_batters,
      hitByPitch: hit_batters,
      atBats: at_bats,
      sacFlies: sacrifice_flies,
      ERA: earned_run_average,
      whip: whip,
      WHIP: whip,
      **{
        "K%" => strikeout_rate,
        "BB%" => walk_rate,
        "K-BB%" => strikeout_rate && walk_rate ? strikeout_rate - walk_rate : nil,
        "K/BB" => safe_divide(totals[:strikeouts], totals[:walks]),
        "BABIP" => babip,
        "LOB%" => lob_percentage
      }
    ).compact
  end

  def sum_game_line_fields(lines, fields)
    fields.to_h { |field| [ field, lines.sum { |line| line.public_send(field).to_i } ] }
  end

  def sum_raw_pitching_stat(lines, key)
    lines.sum { |line| line.raw_data.dig("stats", "pitching", key).to_f }
  end

  def safe_divide(numerator, denominator)
    return nil if denominator.to_f.zero?

    (numerator.to_f / denominator.to_f).round(4)
  end

  def career_rows(category)
    all_season_rows.select { |row| row.stat_type.category == category }
  end

  def career_rows_by_season(category)
    @career_rows_by_season ||= {}
    @career_rows_by_season[category] ||= career_rows(category).group_by(&:season)
  end

  def serialized_season_stats(category)
    definitions = PlayerSeasonStatsLeaderboardQuery::COLUMN_DEFINITIONS_BY_CATEGORY.fetch(category)

    definitions.filter_map do |definition|
      row = best_stat_row(category, Array(definition.fetch(:aliases)))
      next if row.nil?

      {
        key: definition.fetch(:key),
        label: definition.fetch(:label),
        value: row.value.to_s("F"),
        scope_type: row.scope_type,
        scope_key: row.scope_key,
        team: serialize_team(row.team),
        updated_at: row.updated_at
      }
    end
  end

  def best_stat_row(category, aliases)
    best_stat_row_from(
      season_rows.select { |row| row.stat_type.category == category },
      aliases
    )
  end

  def best_stat_row_from(rows, aliases)
    rows_for_preferred_alias(rows, aliases)
      .min_by { |row| [ scope_priority(row), -row.updated_at.to_f ] }
  end

  def rows_for_preferred_alias(rows, aliases)
    aliases.each do |alias_name|
      matching_rows = rows.select { |row| row.stat_type.name == alias_name }
      return matching_rows if matching_rows.any?
    end

    []
  end

  def scope_priority(row)
    return 0 if row.scope_type == "combined"
    return 1 if row.scope_type == "team" && row.team_id == player.team_id
    return 2 if row.scope_type == "team"

    3
  end

  def preferred_category
    @preferred_category ||= begin
      position_type = player.primary_position&.position_type
      %w[pitcher two_way].include?(position_type) ? "pitching" : "batting"
    end
  end

  def memberships
    @memberships ||= player.team_memberships
      .includes(:team)
      .order(starts_on: :desc, id: :desc)
      .to_a
  end

  def organization_tenures
    groups = memberships.sort_by { |membership| [ membership.starts_on, membership.id ] }.each_with_object([]) do |membership, output|
      previous = output.last
      if mergeable_organization_window?(previous, membership)
        if transaction_history_membership?(membership)
          previous[:starts_on] = membership.starts_on
          previous[:ends_on] = membership.ends_on
          previous[:transaction_history] = true
        elsif !previous[:transaction_history]
          previous[:starts_on] = [ previous[:starts_on], membership.starts_on ].min
          previous[:ends_on] = merged_membership_end(previous[:ends_on], membership.ends_on)
        end
        previous[:latest_membership] = membership
        previous[:current] ||= membership == current_membership
      else
        output << {
          starts_on: membership.starts_on,
          ends_on: membership.ends_on,
          latest_membership: membership,
          current: membership == current_membership,
          transaction_history: transaction_history_membership?(membership)
        }
      end
    end

    close_superseded_open_windows(groups)

    groups.reverse.map do |group|
      serialized = serialize_membership(group[:latest_membership]).merge(
        starts_on: group[:starts_on],
        ends_on: group[:ends_on],
        current: group[:current]
      )
      next serialized if group[:current]

      serialized.merge(
        roster_status: "organization",
        injured: false,
        source_status_description: "Organization tenure"
      )
    end
  end

  def close_superseded_open_windows(groups)
    groups.each_cons(2) do |group, following_group|
      next unless group[:ends_on].nil?
      next if group[:latest_membership].team_id == following_group[:latest_membership].team_id

      inferred_end = following_group[:starts_on] - 1.day
      group[:ends_on] = inferred_end if inferred_end >= group[:starts_on]
    end
  end

  def mergeable_organization_window?(group, membership)
    return false if group.nil? || group[:latest_membership].team_id != membership.team_id
    return true if group[:ends_on].nil?

    membership.starts_on <= group[:ends_on] + 1.day
  end

  def merged_membership_end(first, second)
    return nil if first.nil? || second.nil?

    [ first, second ].max
  end

  def transaction_history_membership?(membership)
    membership.source_name == TRANSACTION_HISTORY_SOURCE_NAME

  end
  def trade_history
    Trade
      .joins(:trade_participants)
      .where(trade_participants: { player_id: player.id })
      .includes(trade_participants: [ :player, :from_team, :to_team ])
      .order(occurred_on: :desc, id: :desc)
      .map { |trade| serialize_trade(trade) }
  end

  def serialize_trade(trade)
    {
      id: trade.id,
      mlb_transaction_id: trade.mlb_transaction_id,
      occurred_on: trade.occurred_on,
      description: trade.description,
      participants: trade.trade_participants.sort_by(&:player_name).map { |participant| serialize_trade_participant(participant) }
    }
  end

  def serialize_trade_participant(participant)
    {
      player: {
        id: participant.player_id,
        mlb_id: participant.player_mlb_id,
        full_name: participant.player&.full_name || participant.player_name
      },
      from_team: serialize_trade_team(
        participant.from_team,
        mlb_id: participant.from_team_mlb_id,
        name: participant.from_team_name
      ),
      to_team: serialize_trade_team(
        participant.to_team,
        mlb_id: participant.to_team_mlb_id,
        name: participant.to_team_name
      )
    }
  end

  def serialize_trade_team(team, mlb_id:, name:)
    return serialize_team(team) if team.present?
    return if mlb_id.nil? && name.blank?
    { id: nil, mlb_id: mlb_id, name: name }
  end


  def current_membership
    @current_membership ||= memberships
      .select { |membership| membership.starts_on <= on && (membership.ends_on.nil? || membership.ends_on >= on) }
      .min_by do |membership|
        [ MlbRosterStatus.priority(membership.roster_status), -membership.starts_on.jd, membership.id ]
      end
  end

  def serialize_membership(membership)
    return nil if membership.nil?

    {
      id: membership.id,
      team: serialize_team(membership.team),
      starts_on: membership.starts_on,
      ends_on: membership.ends_on,
      current: membership == current_membership,
      roster_status: membership.roster_status,
      injured: membership.injured?,
      jersey_number: membership.jersey_number,
      primary_position: membership.primary_position,
      secondary_positions: membership.secondary_positions,
      source_name: membership.source_name,
      source_status_code: membership.source_status_code,
      source_status_description: membership.source_status_description,
      last_synced_at: membership.last_synced_at
    }
  end

  def serialize_team(team)
    return nil if team.nil?

    {
      id: team.id,
      mlb_id: team.mlb_id,
      name: team.name,
      abbreviation: team.abbreviation,
      team_name: team.team_name,
      location_name: team.location_name,
      short_name: team.short_name
    }
  end

  def recent_pitch_indicators
    {
      sample_size: PITCH_SAMPLE_SIZE,
      primary_role: preferred_category == "pitching" ? "pitcher" : "batter",
      pitching: pitching_indicators,
      batting: batting_indicators
    }
  end

  def pitching_indicators
    rows = recent_pitcher_rows
    velocities = numeric_values(rows, :release_speed)
    spin_rates = numeric_values(rows, :release_spin_rate)

    {
      pitch_count: rows.length,
      game_count: rows.map(&:game_pk).compact.uniq.length,
      latest_game_date: rows.filter_map(&:game_date).max,
      average_velocity: average(velocities),
      max_velocity: rounded(velocities.max),
      average_spin_rate: average(spin_rates),
      strike_percentage: percentage(rows.count { |row| %w[S X].include?(row.type) }, rows.length)
    }
  end

  def batting_indicators
    rows = recent_batter_rows
    batted_balls = rows.select { |row| DailyAnalyticsCalculator.batted_ball?(row) }
    exit_velocities = numeric_values(batted_balls, :launch_speed)
    launch_angles = numeric_values(batted_balls, :launch_angle)

    {
      pitches_seen: rows.length,
      game_count: rows.map(&:game_pk).compact.uniq.length,
      latest_game_date: rows.filter_map(&:game_date).max,
      batted_ball_count: batted_balls.length,
      average_exit_velocity: average(exit_velocities),
      max_exit_velocity: rounded(exit_velocities.max),
      average_launch_angle: average(launch_angles),
      hard_hit_percentage: percentage(exit_velocities.count { |value| value >= 95.0 }, exit_velocities.length)
    }
  end

  def batter_splits_payload
    rows = BatterSplitSummary
      .where(player: player, metric_date: analysis_range.start_date..analysis_range.end_date)
      .where(calculation_version: DailyAnalyticsRefresh::CALCULATION_VERSION)
      .to_a

    dimensions = [
      [ "pitcher_hand", "Vs. pitcher handedness", { "L" => "Left-handed", "R" => "Right-handed" } ],
      [ "home_away", "Home / away", { "home" => "Home", "away" => "Away" } ],
      [ "day_night", "Day / night", { "day" => "Day", "night" => "Night" } ]
    ]

    {
      available: rows.any? || rolling_batter_rows.any?,
      dimensions: dimensions.filter_map do |split_type, label, options|
        grouped = rows.select { |row| row.split_type == split_type }.group_by(&:split_value)
        {
          key: split_type,
          label: label,
          options: options.filter_map do |value, option_label|
            split_rows = grouped[value]
            next if split_rows.blank?

            { value: value, label: option_label, metrics: aggregate_batter_split_rows(split_rows) }
          end
        }
      end + rolling_game_split_dimensions(rolling_batter_rows, pitching: false)
    }
  end

  def pitcher_splits_payload
    rows = PitcherSplitSummary
      .where(player: player, metric_date: analysis_range.start_date..analysis_range.end_date)
      .where(calculation_version: DailyAnalyticsRefresh::CALCULATION_VERSION)
      .to_a

    dimensions = [
      [ "batter_hand", "Vs. batter handedness", { "L" => "Left-handed", "R" => "Right-handed" } ],
      [ "home_away", "Home / away", { "home" => "Home", "away" => "Away" } ],
      [ "day_night", "Day / night", { "day" => "Day", "night" => "Night" } ]
    ]

    {
      available: rows.any? || rolling_pitcher_rows.any?,
      dimensions: dimensions.filter_map do |split_type, label, options|
        grouped = rows.select { |row| row.split_type == split_type }.group_by(&:split_value)
        {
          key: split_type,
          label: label,
          options: options.filter_map do |value, option_label|
            split_rows = grouped[value]
            next if split_rows.blank?

            { value: value, label: option_label, metrics: aggregate_pitcher_split_rows(split_rows) }
          end
        }
      end + rolling_game_split_dimensions(rolling_pitcher_rows, pitching: true)
    }
  end

  def aggregate_batter_split_rows(rows)
    counts = %i[pitches_seen plate_appearances swings whiffs batted_balls hits home_runs walks strikeouts].to_h do |key|
      [ key, rows.sum { |row| metric_number(row, key) } ]
    end
    swing_percentage = ratio_as_percentage(counts[:swings], counts[:pitches_seen])
    whiff_percentage = ratio_as_percentage(counts[:whiffs], counts[:swings])
    chase_opportunities = rows.sum { |row| metric_number(row, :chase_opportunities) }
    chases = rows.sum { |row| metric_number(row, :chases) }
    batted_balls = counts[:batted_balls]
    hard_hit_balls = rows.sum do |row|
      metric_number(row, :hard_hit_percentage) * batted_balls_for(row) / 100.0
    end

    counts.merge(
      batting_average: ratio(counts[:hits], counts[:plate_appearances] - counts[:walks]),
      swing_percentage: swing_percentage,
      whiff_percentage: whiff_percentage,
      chase_percentage: ratio_as_percentage(chases, chase_opportunities),
      hard_hit_percentage: ratio_as_percentage(hard_hit_balls, batted_balls),
      average_exit_velocity: weighted_average(rows, :average_exit_velocity, :exit_velocity_sample_size),
      estimated_woba: weighted_average(rows, :estimated_woba, :sample_size)
    )
  end

  def aggregate_pitcher_split_rows(rows)
    counts = %i[pitch_count batters_faced swings whiffs strikeouts walks].to_h do |key|
      [ key, rows.sum { |row| metric_number(row, key) } ]
    end
    chase_opportunities = rows.sum { |row| metric_number(row, :chase_opportunities) }
    chases = rows.sum { |row| metric_number(row, :chases) }

    counts.merge(
      zone_percentage: ratio_as_percentage(rows.sum { |row| metric_number(row, :zone_percentage) * metric_number(row, :pitch_count) / 100.0 }, counts[:pitch_count]),
      whiff_percentage: ratio_as_percentage(counts[:whiffs], counts[:swings]),
      chase_percentage: ratio_as_percentage(chases, chase_opportunities),
      average_velocity: weighted_average(rows, :average_velocity, :velocity_sample_size),
      maximum_velocity: rows.filter_map { |row| row.metrics.to_h["maximum_velocity"]&.to_f }.max,
      average_spin_rate: weighted_average(rows, :average_spin_rate, :spin_sample_size),
      delta_run_expectancy_per_100: weighted_average(rows, :delta_run_expectancy_per_100, :pitch_count)
    )
  end

  def rolling_game_split_dimensions(rows, pitching:)
    game_ids = rows.sort_by { |row| [ row.game_date || Date.new(1900, 1, 1), row.game_pk ] }
      .reverse
      .map(&:game_pk)
      .uniq

    [ 7, 15, 30 ].map do |game_count|
      selected_game_ids = game_ids.first(game_count)
      metrics = if selected_game_ids.any?
        selected_rows = rows.select { |row| selected_game_ids.include?(row.game_pk) }
        pitching ? aggregate_raw_pitcher_split_rows(selected_rows) : aggregate_raw_batter_split_rows(selected_rows)
      end

      {
        key: "last_#{game_count}_games",
        label: "Last #{game_count} games",
        options: metrics ? [{ value: "all", label: "Last #{game_count} games", metrics: metrics }] : []
      }
    end
  end

  def aggregate_raw_batter_split_rows(rows)
    swings = rows.count { |row| DailyAnalyticsCalculator.swing?(row) }
    whiffs = rows.count { |row| DailyAnalyticsCalculator.whiff?(row) }
    batted_balls = rows.select { |row| DailyAnalyticsCalculator.batted_ball?(row) }
    chase_opportunities = rows.count { |row| chase_opportunity_for?(row) }
    chases = rows.count { |row| chase_opportunity_for?(row) && DailyAnalyticsCalculator.swing?(row) }

    {
      pitches_seen: rows.length,
      plate_appearances: raw_plate_appearance_count(rows),
      swings: swings,
      whiffs: whiffs,
      batted_balls: batted_balls.length,
      hits: raw_terminal_event_count(rows, HIT_EVENTS),
      home_runs: raw_terminal_event_count(rows, [ "home_run" ]),
      walks: raw_terminal_event_count(rows, %w[walk intent_walk intentional_walk]),
      strikeouts: raw_terminal_event_count(rows, %w[strikeout strikeout_double_play]),
      swing_percentage: ratio_as_percentage(swings, rows.length),
      whiff_percentage: ratio_as_percentage(whiffs, swings),
      chase_percentage: ratio_as_percentage(chases, chase_opportunities),
      hard_hit_percentage: ratio_as_percentage(batted_balls.count { |row| row.launch_speed.to_f >= 95 }, batted_balls.length),
      average_exit_velocity: average_raw(batted_balls, :launch_speed),
      estimated_woba: average_raw(rows, :estimated_woba_using_speedangle)
    }
  end

  def aggregate_raw_pitcher_split_rows(rows)
    swings = rows.count { |row| DailyAnalyticsCalculator.swing?(row) }
    whiffs = rows.count { |row| DailyAnalyticsCalculator.whiff?(row) }
    chase_opportunities = rows.count { |row| chase_opportunity_for?(row) }
    chases = rows.count { |row| chase_opportunity_for?(row) && DailyAnalyticsCalculator.swing?(row) }

    {
      pitch_count: rows.length,
      batters_faced: raw_plate_appearance_count(rows),
      zone_percentage: ratio_as_percentage(rows.count { |row| row.zone.to_i.between?(1, 9) }, rows.length),
      swings: swings,
      whiffs: whiffs,
      strikeouts: raw_terminal_event_count(rows, %w[strikeout strikeout_double_play]),
      walks: raw_terminal_event_count(rows, %w[walk intent_walk intentional_walk]),
      whiff_percentage: ratio_as_percentage(whiffs, swings),
      chase_percentage: ratio_as_percentage(chases, chase_opportunities),
      average_velocity: average_raw(rows, :release_speed),
      maximum_velocity: numeric_values_for(rows, :release_speed).max,
      average_spin_rate: average_raw(rows, :release_spin_rate),
      delta_run_expectancy_per_100: average_raw(rows, :delta_run_exp)&.then { |value| (value * 100).round(1) }
    }
  end

  def rolling_batter_rows
    @rolling_batter_rows ||= rolling_rows_for(:batter)
  end

  def rolling_pitcher_rows
    @rolling_pitcher_rows ||= rolling_rows_for(:pitcher)
  end

  def rolling_rows_for(player_field)
    return [] if player.mlb_id.blank?

    PitchDatum.where(player_field => player.mlb_id, game_date: analysis_range.start_date..analysis_range.end_date)
      .order(game_date: :desc, game_pk: :desc, at_bat_number: :desc, pitch_number: :desc)
      .to_a
  end

  def raw_plate_appearance_count(rows)
    rows.map { |row| [ row.game_pk, row.at_bat_number ] }.uniq.length
  end

  def raw_terminal_event_count(rows, event_names)
    rows.select { |row| event_names.include?(row.events.to_s.downcase) }
      .map { |row| [ row.game_pk, row.at_bat_number ] }.uniq.length
  end

  def chase_opportunity_for?(row)
    row.zone.present? && !row.zone.to_i.between?(1, 9)
  end

  def numeric_values_for(rows, field)
    rows.filter_map { |row| row.public_send(field)&.to_f }
  end

  def average_raw(rows, field)
    values = numeric_values_for(rows, field)
    values.any? ? (values.sum / values.length).round(1) : nil
  end

  def batted_balls_for(row)
    metric_number(row, :batted_balls)
  end

  def ratio_as_percentage(numerator, denominator)
    return nil if denominator.to_f.zero?

    (numerator.to_f / denominator.to_f * 100).round(1)
  end

  def metric_number(row, key)
    value = row.metrics.to_h[key.to_s] || row.metrics.to_h[key]
    value.to_f
  end

  def ratio(numerator, denominator)
    return nil if denominator.to_f <= 0

    (numerator.to_f / denominator.to_f).round(3)
  end

  def weighted_average(rows, metric_key, weight_key)
    weighted_total = rows.sum do |row|
      metric = row.metrics.to_h[metric_key.to_s] || row.metrics.to_h[metric_key]
      weight = metric_number(row, weight_key)
      metric.present? ? metric.to_f * weight : 0
    end
    total_weight = rows.sum { |row| metric_number(row, weight_key) }
    return nil if total_weight.zero?

    (weighted_total / total_weight).round(1)
  end

  def recent_pitcher_rows
    @recent_pitcher_rows ||= recent_pitch_scope.where(pitcher: player.mlb_id).to_a
  end

  def recent_batter_rows
    @recent_batter_rows ||= recent_pitch_scope.where(batter: player.mlb_id).to_a
  end

  def recent_pitch_scope
    PitchDatum.order(game_date: :desc, game_pk: :desc, at_bat_number: :desc, pitch_number: :desc).limit(PITCH_SAMPLE_SIZE)
  end

  def numeric_values(rows, attribute)
    rows.filter_map { |row| row.public_send(attribute)&.to_f }
  end

  def average(values)
    return nil if values.empty?

    rounded(values.sum / values.length)
  end

  def percentage(numerator, denominator)
    return nil if denominator.zero?

    rounded((numerator.to_f / denominator) * 100)
  end

  def rounded(value)
    value&.round(1)
  end

  def source_metadata
    datasets = source_datasets.compact

    {
      last_updated_at: datasets.filter_map { |dataset| dataset[:last_updated_at] }.max,
      sources: datasets.filter_map { |dataset| dataset[:source_name] }.uniq,
      datasets: datasets
    }
  end

  def source_datasets
    [
      dataset("player", "NineLens", player.updated_at),
      dataset("profile", "NineLens", player.profile&.last_synced_at),
      dataset_for_records("positions", player.player_positions.to_a, :source_name, :last_synced_at),
      dataset_for_records("memberships", memberships, :source_name, :last_synced_at),
      dataset_for_records("season_stats", all_season_rows, nil, :updated_at, source_name: "Imported season stats"),
      benchmark_dataset,
      pitch_dataset
    ]
  end

  def dataset(name, source_name, last_updated_at)
    return nil if last_updated_at.nil?

    { name: name, source_name: source_name, last_updated_at: last_updated_at }
  end

  def dataset_for_records(name, records, source_attribute, timestamp_attribute, source_name: nil)
    return nil if records.empty?

    sources = source_name || records.filter_map { |record| record.public_send(source_attribute) }.uniq.join(", ")
    dataset(name, sources.presence, records.filter_map { |record| record.public_send(timestamp_attribute) }.max)
  end

  def pitch_dataset
    rows = (recent_pitcher_rows + recent_batter_rows).uniq(&:id)
    return nil if rows.empty?

    timestamp = rows.filter_map { |row| row.fetched_at_utc || row.updated_at }.max
    dataset("pitch_data", "Baseball Savant", timestamp)
  end

  def benchmark_dataset
    record = player.player_metric_percentiles
      .for_version(DailyAnalyticsRefresh::CALCULATION_VERSION)
      .order(calculated_at: :desc)
      .first
    dataset("contextual_benchmarks", record&.source_name, record&.calculated_at)
  end
end
