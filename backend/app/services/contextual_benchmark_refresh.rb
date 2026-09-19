class ContextualBenchmarkRefresh
  SOURCE_NAME = "NineLens contextual benchmarks"
  METRICS = {
    "ops" => { group: "batting", label: "OPS", direction: "higher_better", unit: "rate" },
    "batter_strikeout_percentage" => { group: "batting", label: "K%", direction: "lower_better", unit: "percent" },
    "batter_walk_percentage" => { group: "batting", label: "BB%", direction: "higher_better", unit: "percent" },
    "average_exit_velocity" => { group: "batting", label: "Average exit velocity", direction: "higher_better", unit: "mph" },
    "maximum_exit_velocity" => { group: "batting", label: "Max exit velocity", direction: "higher_better", unit: "mph" },
    "barrel_percentage" => { group: "batting", label: "Barrel rate", direction: "higher_better", unit: "percent" },
    "hard_hit_percentage" => { group: "batting", label: "Hard-hit rate", direction: "higher_better", unit: "percent" },
    "average_bat_speed" => { group: "batting", label: "Bat speed", direction: "higher_better", unit: "mph" },
    "batter_whiff_percentage" => { group: "batting", label: "Whiff rate", direction: "lower_better", unit: "percent" },
    "batter_chase_percentage" => { group: "batting", label: "Chase rate", direction: "lower_better", unit: "percent" },
    "pitcher_average_velocity" => { group: "pitching", label: "Average velocity", direction: "higher_better", unit: "mph" },
    "pitcher_strikeout_percentage" => { group: "pitching", label: "K%", direction: "higher_better", unit: "percent" },
    "pitcher_walk_percentage" => { group: "pitching", label: "BB%", direction: "lower_better", unit: "percent" },
    "pitcher_average_spin_rate" => { group: "pitching", label: "Average spin rate", direction: "neutral", unit: "rpm" },
    "pitcher_whiff_percentage" => { group: "pitching", label: "Whiff rate", direction: "higher_better", unit: "percent" },
    "pitcher_chase_percentage" => { group: "pitching", label: "Chase rate", direction: "higher_better", unit: "percent" },
    "pitch_usage_percentage" => { group: "pitch_type", label: "Pitch usage", direction: "neutral", unit: "percent" }
  }.freeze
  BATTING_TOTAL_KEYS = %w[plate_appearances at_bats hits doubles triples home_runs walks strikeouts hit_by_pitch sacrifice_flies].freeze
  BATTER_QUALIFIER_PER_TEAM_GAME = 2.1
  PITCHER_QUALIFIER_PER_TEAM_GAME = 1.25
  SEASON_STAT_NAMES = {
    "plate_appearances" => "plateAppearances",
    "at_bats" => "atBats",
    "hits" => "hits",
    "doubles" => "doubles",
    "triples" => "triples",
    "home_runs" => "homeRuns",
    "walks" => "baseOnBalls",
    "strikeouts" => "strikeOuts",
    "hit_by_pitch" => "hitByPitch",
    "sacrifice_flies" => "sacFlies"
  }.freeze

  def self.call(start_date:, end_date:, calculation_version: DailyAnalyticsRefresh::CALCULATION_VERSION)
    new(start_date: start_date, end_date: end_date, calculation_version: calculation_version).call
  end

  def self.preview(player_id:, start_date:, end_date:, calculation_version: DailyAnalyticsRefresh::CALCULATION_VERSION)
    new(start_date: start_date, end_date: end_date, calculation_version: calculation_version).preview_for(player_id)
  end

  def initialize(start_date:, end_date:, calculation_version:)
    @start_date = parse_date(start_date)
    @end_date = parse_date(end_date)
    @calculation_version = calculation_version.to_s.strip
    @calculated_at = Time.current
  end

  def call
    return failure("End date must be on or after start date") if end_date < start_date
    return failure("Calculation version is required") if calculation_version.blank?

    current = qualified_observations
    benchmark_count = 0
    percentile_count = 0

    ApplicationRecord.transaction do
      remove_existing!
      grouped_observations(current).each do |identity, metric_rows|
        peer_groups(metric_rows).each do |peer_group_type, peer_group_key, peers|
          benchmark = create_benchmark!(identity, peer_group_type, peer_group_key, peers)
          benchmark_count += 1
          percentile_count += create_percentiles!(benchmark, peers)
        end
      end
    end

    {
      success: true,
      message: "Refreshed contextual benchmarks for #{start_date.iso8601} through #{end_date.iso8601}",
      data: {
        source_start_date: start_date.iso8601,
        source_end_date: end_date.iso8601,
        calculation_version: calculation_version,
        benchmark_count: benchmark_count,
        percentile_count: percentile_count,
        player_count: current.map { |row| row[:player_id] }.uniq.length
      }
    }
  rescue ArgumentError => error
    failure(error.message)
  rescue ActiveRecord::ActiveRecordError => error
    failure("Failed to refresh contextual benchmarks: #{error.message}")
  end

  def preview_for(player_id)
    return preview_result([]) if end_date < start_date || calculation_version.blank?

    all_observations = observations(start_date, end_date)
    current = qualified_observations
    metrics = grouped_observations(current).filter_map do |_identity, metric_rows|
      player_row = metric_rows.find { |row| row[:player_id] == player_id }
      next if player_row.nil?

      groups = peer_groups(metric_rows)
      league = groups.find { |type, _key, _peers| type == "mlb" }
      position = groups.find { |type, _key, peers| type == "position" && peers.include?(player_row) }
      role = groups.find { |type, _key, peers| type == "pitcher_role" && peers.include?(player_row) }
      preview_metric(player_row, league, position, role)
    end
    sorted_metrics = metrics.sort_by { |metric| [ metric[:metric_group], metric[:display_name], metric[:dimension_value].to_s ] }
    unavailable_reason = if sorted_metrics.empty? && all_observations.any? { |row| row[:player_id] == player_id } && !current.any? { |row| row[:player_id] == player_id }
      benchmark_eligibility_message(all_observations.select { |row| row[:player_id] == player_id })
    end

    preview_result(sorted_metrics, unavailable_reason: unavailable_reason)
  end

  private

  attr_reader :start_date, :end_date, :calculation_version, :calculated_at

  def preview_result(metrics, unavailable_reason: nil)
    {
      available: metrics.any?,
      cached: false,
      source_start_date: start_date,
      source_end_date: end_date,
      calculation_version: calculation_version,
      calculated_at: calculated_at,
      metrics: metrics,
      unavailable_reason: unavailable_reason
    }
  end

  def benchmark_eligibility_message(player_observations)
    if player_observations.any? { |row| %w[pitching pitch_type].include?(row[:metric_group]) }
      "Benchmarks are not shown because this player has not yet met the minimum pitching sample-size requirement of 1.25 appearances per team game."
    else
      "Benchmarks are not shown because this player has not yet met the minimum batting sample-size requirement of 2.1 appearances per team game."
    end
  end

  def preview_metric(player_row, league, position, role)
    definition = METRICS.fetch(player_row[:metric_key])
    league_type, league_key, league_peers = league
    position_type, position_key, position_peers = position
    role_type, role_key, role_peers = role
    {
      metric_key: player_row[:metric_key],
      metric_group: player_row[:metric_group],
      display_name: player_row[:display_name],
      unit: definition.fetch(:unit),
      directionality: player_row[:directionality],
      dimension_type: player_row[:dimension_type].presence,
      dimension_value: player_row[:dimension_value].presence,
      raw_value: player_row[:value],
      mlb_average: benchmark_average(player_row[:metric_key], league_peers),
      position_average: position_type ? benchmark_average(player_row[:metric_key], position_peers) : nil,
      position_key: position_key,
      pitcher_role_average: role_type ? benchmark_average(player_row[:metric_key], role_peers) : nil,
      pitcher_role_key: role_key,
      percentile: percentile(player_row[:value], league_peers.map { |row| row[:value] }, player_row[:directionality]),
      position_percentile: position_type ? percentile(player_row[:value], position_peers.map { |row| row[:value] }, player_row[:directionality]) : nil,
      pitcher_role_percentile: role_type ? percentile(player_row[:value], role_peers.map { |row| row[:value] }, player_row[:directionality]) : nil,
      sample_size: player_row[:sample_size],
      mlb_sample_size: league_peers.sum { |row| row[:sample_size] },
      mlb_player_count: league_peers.length,
      position_player_count: position_peers&.length,
      pitcher_role_player_count: role_peers&.length
    }
  end

  def observations(range_start, range_end)
    batting_observations(range_start, range_end) +
      pitching_observations(range_start, range_end) +
      batter_statcast_observations(range_start, range_end) +
      pitcher_statcast_observations(range_start, range_end) +
      pitch_usage_observations(range_start, range_end)
  end

  def qualified_observations
    observations(start_date, end_date).select do |row|
      eligible_player_ids_for(row[:metric_group]).include?(row[:player_id])
    end
  end

  def eligible_player_ids_for(metric_group)
    case metric_group
    when "batting"
      qualified_player_ids(PlayerBattingDaily, BATTER_QUALIFIER_PER_TEAM_GAME)
    when "pitching", "pitch_type"
      qualified_player_ids(PlayerPitchingDaily, PITCHER_QUALIFIER_PER_TEAM_GAME)
    else
      Set.new
    end
  end

  def qualified_player_ids(model, qualifier_per_team_game)
    @qualified_player_ids ||= {}
    @qualified_player_ids[[ model.name, qualifier_per_team_game ]] ||= begin
      rows = daily_rows(model, start_date, end_date)
      team_game_counts = games_by_team(rows.map(&:team_id).uniq)

      rows.group_by(&:player_id).each_with_object(Set.new) do |(player_id, player_rows), eligible_ids|
        games = player_rows.map(&:team_id).uniq.map do |team_id|
          team_game_counts.fetch(team_id) { player_rows.select { |row| row.team_id == team_id }.map(&:metric_date).uniq.length }
        end.max.to_i
        next if games.zero?

        appearances = player_rows.sum(&:sample_size)
        eligible_ids << player_id if appearances >= games * qualifier_per_team_game
      end
    end
  end

  def games_by_team(team_ids)
    counts = Hash.new(0)
    Game.where(official_date: start_date..end_date)
      .where("home_team_id IN (:team_ids) OR away_team_id IN (:team_ids)", team_ids: team_ids)
      .pluck(:home_team_id, :away_team_id)
      .each do |home_team_id, away_team_id|
        counts[home_team_id] += 1 if team_ids.include?(home_team_id)
        counts[away_team_id] += 1 if team_ids.include?(away_team_id)
      end
    counts
  end

  def batting_observations(range_start, range_end)
    official_totals = full_season_range?(range_start, range_end) ? season_batting_totals(end_date.year) : {}
    daily_rows(PlayerBattingDaily, range_start, range_end).group_by(&:player_id).flat_map do |player_id, rows|
      totals = official_totals[player_id] || sum_metrics(rows, BATTING_TOTAL_KEYS)
      next [] if totals["plate_appearances"].zero?

      observations = [
        rate_observation(player_id, "batter_strikeout_percentage", totals["strikeouts"], totals["plate_appearances"], scale: 100),
        rate_observation(player_id, "batter_walk_percentage", totals["walks"], totals["plate_appearances"], scale: 100)
      ]
      if totals["at_bats"].positive?
        value = ops(totals)
        observations.unshift(observation(
          player_id: player_id,
          metric_key: "ops",
          value: value,
          sample_size: totals["plate_appearances"],
          numerator: value * totals["plate_appearances"],
          denominator: totals["plate_appearances"],
          components: totals
        ))
      end
      observations.compact
    end
  end

  def pitching_observations(range_start, range_end)
    daily_rows(PlayerPitchingDaily, range_start, range_end).group_by(&:player_id).flat_map do |player_id, rows|
      batters_faced = sum_metric(rows, "batters_faced")
      next [] if batters_faced.zero?

      [
        rate_observation(player_id, "pitcher_strikeout_percentage", sum_metric(rows, "strikeouts"), batters_faced, scale: 100),
        rate_observation(player_id, "pitcher_walk_percentage", sum_metric(rows, "walks"), batters_faced, scale: 100)
      ].compact
    end
  end

  def batter_statcast_observations(range_start, range_end)
    rows = daily_rows(BatterSplitSummary, range_start, range_end).select { |row| row.split_type == "home_away" }
    rows.group_by(&:player_id).flat_map do |player_id, player_rows|
      batted_balls = sum_metric(player_rows, "exit_velocity_sample_size", fallback: "batted_balls")
      swings = sum_metric(player_rows, "swings")
      chase_opportunities = sum_metric(player_rows, "chase_opportunities")
      exit_velocity_sum = weighted_metric_sum(player_rows, "average_exit_velocity", "exit_velocity_sample_size", fallback: "batted_balls")
      maximum_exit_velocity = maximum_metric(player_rows, "maximum_exit_velocity")
      barrels = sum_metric(player_rows, "barrel_count")
      barrel_samples = sum_metric(player_rows, "barrel_sample_size", fallback: "batted_balls")
      hard_hit_sum = weighted_percentage_sum(player_rows, "hard_hit_percentage", "batted_balls")
      bat_speed_samples = sum_metric(player_rows, "bat_speed_sample_size")
      bat_speed_sum = weighted_metric_sum(player_rows, "average_bat_speed", "bat_speed_sample_size")
      whiffs = sum_metric(player_rows, "whiffs")
      chases = sum_metric(player_rows, "chases")

      [
        rate_observation(player_id, "average_exit_velocity", exit_velocity_sum, batted_balls),
        value_observation(player_id, "maximum_exit_velocity", maximum_exit_velocity, sample_size: batted_balls),
        rate_observation(player_id, "barrel_percentage", barrels, barrel_samples, scale: 100),
        rate_observation(player_id, "hard_hit_percentage", hard_hit_sum, batted_balls, scale: 100),
        rate_observation(player_id, "average_bat_speed", bat_speed_sum, bat_speed_samples),
        rate_observation(player_id, "batter_whiff_percentage", whiffs, swings, scale: 100),
        rate_observation(player_id, "batter_chase_percentage", chases, chase_opportunities, scale: 100)
      ].compact
    end
  end

  def pitcher_statcast_observations(range_start, range_end)
    rows = daily_rows(PitcherSplitSummary, range_start, range_end).select { |row| row.split_type == "home_away" }
    rows.group_by(&:player_id).flat_map do |player_id, player_rows|
      velocity_samples = sum_metric(player_rows, "velocity_sample_size", fallback: "pitch_count")
      spin_samples = sum_metric(player_rows, "spin_sample_size", fallback: "pitch_count")
      swings = sum_metric(player_rows, "swings")
      chase_opportunities = sum_metric(player_rows, "chase_opportunities")

      [
        rate_observation(player_id, "pitcher_average_velocity", weighted_metric_sum(player_rows, "average_velocity", "velocity_sample_size", fallback: "pitch_count"), velocity_samples),
        rate_observation(player_id, "pitcher_average_spin_rate", weighted_metric_sum(player_rows, "average_spin_rate", "spin_sample_size", fallback: "pitch_count"), spin_samples),
        rate_observation(player_id, "pitcher_whiff_percentage", sum_metric(player_rows, "whiffs"), swings, scale: 100),
        rate_observation(player_id, "pitcher_chase_percentage", sum_metric(player_rows, "chases"), chase_opportunities, scale: 100)
      ].compact
    end
  end

  def pitch_usage_observations(range_start, range_end)
    rows = daily_rows(PitcherPitchTypeDaily, range_start, range_end)
    totals_by_player = rows.group_by(&:player_id).transform_values { |player_rows| sum_metric(player_rows, "pitch_count") }

    rows.group_by { |row| [ row.player_id, row.pitch_type ] }.filter_map do |(player_id, pitch_type), pitch_rows|
      total_pitches = totals_by_player.fetch(player_id)
      type_pitches = sum_metric(pitch_rows, "pitch_count")
      next if total_pitches.zero?

      rate_observation(
        player_id,
        "pitch_usage_percentage",
        type_pitches,
        total_pitches,
        scale: 100,
        dimension_type: "pitch_type",
        dimension_value: pitch_type
      )
    end
  end

  def daily_rows(model, range_start, range_end)
    model.where(metric_date: range_start..range_end, calculation_version: calculation_version).to_a
  end

  def observation(player_id:, metric_key:, value:, sample_size:, numerator:, denominator:, components: nil, dimension_type: "", dimension_value: "")
    definition = METRICS.fetch(metric_key)
    {
      player_id: player_id,
      metric_key: metric_key,
      metric_group: definition.fetch(:group),
      display_name: definition.fetch(:label),
      directionality: definition.fetch(:direction),
      unit: definition.fetch(:unit),
      dimension_type: dimension_type,
      dimension_value: dimension_value,
      value: round(value),
      sample_size: sample_size.to_i,
      numerator: numerator.to_f,
      denominator: denominator.to_f,
      components: components
    }
  end

  def rate_observation(player_id, metric_key, numerator, denominator, scale: 1, dimension_type: "", dimension_value: "")
    return if denominator.to_f <= 0

    observation(
      player_id: player_id,
      metric_key: metric_key,
      value: numerator.to_f / denominator * scale,
      sample_size: denominator.to_i,
      numerator: numerator.to_f * scale,
      denominator: denominator,
      dimension_type: dimension_type,
      dimension_value: dimension_value
    )
  end

  def value_observation(player_id, metric_key, value, sample_size:, dimension_type: "", dimension_value: "")
    return if value.nil?

    observation(
      player_id: player_id,
      metric_key: metric_key,
      value: value,
      sample_size: sample_size,
      numerator: value,
      denominator: 1,
      dimension_type: dimension_type,
      dimension_value: dimension_value
    )
  end

  def grouped_observations(rows)
    rows.group_by { |row| [ row[:metric_key], row[:dimension_type], row[:dimension_value] ] }
  end

  def peer_groups(rows)
    groups = [ [ "mlb", "all", rows ] ]
    if rows.first[:metric_group] == "batting"
      rows.group_by { |row| position_by_player[row[:player_id]] }.each do |position, peers|
        groups << [ "position", position, peers ] if position.present?
      end
    else
      rows.group_by { |row| pitcher_role_by_player[row[:player_id]] }.each do |role, peers|
        groups << [ "pitcher_role", role, peers ] if role.present?
      end
    end
    groups
  end

  def create_benchmark!(identity, peer_group_type, peer_group_key, peers)
    metric_key, dimension_type, dimension_value = identity
    definition = METRICS.fetch(metric_key)
    LeagueMetricBenchmark.create!(
      metric_key: metric_key,
      metric_group: definition.fetch(:group),
      display_name: definition.fetch(:label),
      peer_group_type: peer_group_type,
      peer_group_key: peer_group_key,
      dimension_type: dimension_type,
      dimension_value: dimension_value,
      directionality: definition.fetch(:direction),
      average_value: benchmark_average(metric_key, peers),
      sample_size: peers.sum { |row| row[:sample_size] },
      player_count: peers.length,
      source_start_date: start_date,
      source_end_date: end_date,
      calculation_version: calculation_version,
      calculated_at: calculated_at,
      source_name: SOURCE_NAME,
      metadata: { unit: definition.fetch(:unit), average_method: metric_key == "ops" ? "pooled_rate" : "sample_weighted" }
    )
  end

  def create_percentiles!(benchmark, peers)
    values = peers.map { |row| row[:value] }
    peers.each do |row|
      PlayerMetricPercentile.create!(
        player_id: row[:player_id],
        league_metric_benchmark: benchmark,
        raw_value: row[:value],
        percentile: percentile(row[:value], values, benchmark.directionality),
        sample_size: row[:sample_size],
        peer_player_count: peers.length,
        source_start_date: start_date,
        source_end_date: end_date,
        calculation_version: calculation_version,
        calculated_at: calculated_at,
        source_name: SOURCE_NAME,
        metadata: { unit: row[:unit], dimension_type: row[:dimension_type], dimension_value: row[:dimension_value] }
      )
    end
    peers.length
  end

  def benchmark_average(metric_key, peers)
    return round(pooled_ops(peers)) if metric_key == "ops"

    denominator = peers.sum { |row| row[:denominator] }
    return 0 if denominator.zero?

    round(peers.sum { |row| row[:numerator] } / denominator)
  end

  def pooled_ops(peers)
    totals = peers.each_with_object(Hash.new(0.0)) do |row, values|
      row.fetch(:components).each { |key, value| values[key] += value.to_f }
    end
    ops(totals)
  end

  def ops(totals)
    at_bats = totals.fetch("at_bats").to_f
    hits = totals.fetch("hits").to_f
    walks = totals.fetch("walks").to_f
    hit_by_pitch = totals.fetch("hit_by_pitch", 0).to_f
    sacrifice_flies = totals.fetch("sacrifice_flies", 0).to_f
    return 0 if at_bats.zero?

    total_bases = hits + totals.fetch("doubles").to_f + (2 * totals.fetch("triples").to_f) + (3 * totals.fetch("home_runs").to_f)
    obp_denominator = at_bats + walks + hit_by_pitch + sacrifice_flies
    obp = obp_denominator.zero? ? 0 : (hits + walks + hit_by_pitch) / obp_denominator
    obp + (total_bases / at_bats)
  end

  def full_season_range?(range_start, range_end)
    range_start == Date.new(range_end.year, 1, 1)
  end

  def season_batting_totals(season)
    rows = PlayerSeasonStat.joins(:stat_type)
      .where(season: season, stat_types: { category: "batting", name: SEASON_STAT_NAMES.values })
      .includes(:stat_type)
      .to_a

    rows.group_by(&:player_id).to_h do |player_id, player_rows|
      scoped_rows = player_rows.group_by { |row| [ row.scope_type, row.scope_key ] }
      rows_for_totals = scoped_rows.find { |(scope_type, _scope_key), _rows| scope_type == "combined" }&.last ||
        player_rows.select { |row| row.scope_type == "team" }
      values = rows_for_totals.group_by { |row| row.stat_type.name }.transform_values { |stat_rows| stat_rows.sum(&:value) }
      totals = SEASON_STAT_NAMES.to_h { |key, stat_name| [ key, values[stat_name].to_f ] }
      [ player_id, totals.stringify_keys ]
    end
  end

  def percentile(value, values, directionality)
    strict = if directionality == "lower_better"
      values.count { |peer| peer > value }
    else
      values.count { |peer| peer < value }
    end
    equal = values.count { |peer| peer == value }
    round((strict + (equal * 0.5)) * 100.0 / values.length, 2)
  end

  def position_by_player
    @position_by_player ||= begin
      current = PlayerPosition.current.primary_assignments
        .joins(:position).pluck(:player_id, "positions.abbreviation").to_h
      seasonal = PlayerPosition.for_season(end_date.year).primary_assignments
        .joins(:position).pluck(:player_id, "positions.abbreviation").to_h
      current.merge(seasonal)
    end
  end

  def pitcher_role_by_player
    @pitcher_role_by_player ||= begin
      rows = daily_rows(PlayerPitchingDaily, start_date, end_date)
      rows.group_by(&:player_id).to_h do |player_id, player_rows|
        games = sum_metric(player_rows, "games")
        starts = sum_metric(player_rows, "games_started")
        role = games.zero? ? nil : (starts.positive? && starts * 2 >= games ? "starter" : "reliever")
        [ player_id, role ]
      end
    end
  end

  def sum_metrics(rows, keys)
    keys.to_h { |key| [ key, sum_metric(rows, key) ] }
  end

  def sum_metric(rows, key, fallback: nil)
    rows.sum do |row|
      value = row.metrics[key]
      value = row.metrics[fallback] if value.nil? && fallback
      value.to_f
    end
  end

  def weighted_metric_sum(rows, metric_key, sample_key, fallback: nil)
    rows.sum do |row|
      sample = row.metrics[sample_key]
      sample = row.metrics[fallback] if sample.nil? && fallback
      row.metrics[metric_key].to_f * sample.to_f
    end
  end

  def weighted_percentage_sum(rows, metric_key, sample_key)
    weighted_metric_sum(rows, metric_key, sample_key) / 100.0
  end

  def maximum_metric(rows, key)
    rows.filter_map { |row| row.metrics[key] }.map(&:to_f).max
  end

  def remove_existing!
    benchmarks = LeagueMetricBenchmark.where(
      source_start_date: start_date,
      source_end_date: end_date,
      calculation_version: calculation_version
    )
    benchmark_ids = benchmarks.pluck(:id)
    PlayerMetricPercentile.where(league_metric_benchmark_id: benchmark_ids).delete_all
    LeagueMetricBenchmark.where(id: benchmark_ids).delete_all
  end

  def parse_date(value)
    return value if value.is_a?(Date)

    Date.iso8601(value.to_s)
  rescue Date::Error
    raise ArgumentError, "Benchmark dates must be valid ISO dates"
  end

  def round(value, precision = 6)
    value.to_f.round(precision)
  end

  def failure(message)
    { success: false, message: message, data: { errors: [ message ] } }
  end
end
