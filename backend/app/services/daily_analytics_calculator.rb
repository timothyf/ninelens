class DailyAnalyticsCalculator
  SWING_DESCRIPTIONS = %w[
    swinging_strike swinging_strike_blocked missed_bunt foul foul_bunt foul_tip
    hit_into_play hit_into_play_no_out hit_into_play_score
  ].freeze
  WHIFF_DESCRIPTIONS = %w[swinging_strike swinging_strike_blocked missed_bunt foul_tip].freeze
  BATTED_BALL_DESCRIPTIONS = %w[
    hit_into_play hit_into_play_no_out hit_into_play_score
  ].freeze
  LIVE_IN_PLAY_DESCRIPTIONS = %w[
    in\ play,\ out(s) in\ play,\ no\ out in\ play,\ run(s)
  ].freeze
  HIT_EVENTS = %w[single double triple home_run].freeze
  WALK_EVENTS = %w[walk intent_walk intentional_walk].freeze
  STRIKEOUT_EVENTS = %w[strikeout strikeout_double_play].freeze
  PITCH_COLUMNS = %i[
    game_pk at_bat_number pitcher batter stand p_throws pitch_type pitch_name
    description events inning_topbot release_speed release_spin_rate release_extension
    pfx_x pfx_z zone launch_speed launch_angle launch_speed_angle bat_speed estimated_woba_using_speedangle delta_run_exp
  ].freeze
  BATTING_LINE_COLUMNS = %i[
    game_id player_id team_id plate_appearances at_bats runs hits doubles triples home_runs
    runs_batted_in walks strikeouts stolen_bases caught_stealing raw_data
  ].freeze
  PITCHING_LINE_COLUMNS = %i[
    game_id player_id team_id starter outs_recorded batters_faced hits runs earned_runs
    home_runs walks strikeouts pitches strikes holds saves blown_saves
  ].freeze
  MODELS = DailyAnalyticsRefresh::SUMMARY_MODELS

  def self.call(metric_date:, calculation_version: DailyAnalyticsRefresh::CALCULATION_VERSION)
    new(metric_date: metric_date, calculation_version: calculation_version).call
  end

  def self.batted_ball?(pitch)
    return false if pitch.launch_speed.blank?

    description = pitch.description.to_s.downcase
    BATTED_BALL_DESCRIPTIONS.include?(description) ||
      LIVE_IN_PLAY_DESCRIPTIONS.include?(description)
  end

  def self.description_key(description)
    normalized = description.to_s.downcase.parameterize(separator: "_")
    return "hit_into_play" if %w[in_play_out_s in_play_no_out in_play_run_s].include?(normalized)

    normalized
  end

  def self.swing?(pitch)
    SWING_DESCRIPTIONS.include?(description_key(pitch.description))
  end

  def self.whiff?(pitch)
    WHIFF_DESCRIPTIONS.include?(description_key(pitch.description))
  end

  def initialize(metric_date:, calculation_version:)
    @metric_date = metric_date.to_date
    @calculation_version = calculation_version
    @calculated_at = Time.current
  end

  def call
    rows = {
      PlayerBattingDaily => batting_rows,
      PlayerPitchingDaily => pitching_rows,
      PitcherPitchTypeDaily => pitcher_pitch_type_rows,
      BatterSplitSummary => batter_split_rows,
      PitcherSplitSummary => pitcher_split_rows,
      TeamDailyMetric => team_rows
    }

    ApplicationRecord.transaction do
      MODELS.each { |model| model.where(metric_date: metric_date, calculation_version: calculation_version).delete_all }
      rows.each { |model, values| model.insert_all(values) if values.any? }
    end

    rows.to_h { |model, values| [ model.table_name, values.length ] }
  end

  private

  attr_reader :metric_date, :calculation_version, :calculated_at

  def batting_rows
    batting_lines.group_by { |line| [ line.player_id, line.team_id ] }.map do |(player_id, team_id), lines|
      totals = sum_fields(lines, %i[plate_appearances at_bats runs hits doubles triples home_runs runs_batted_in walks strikeouts stolen_bases caught_stealing])
        .merge(batting_line_official_totals(lines))
      total_bases = totals[:hits] + totals[:doubles] + (2 * totals[:triples]) + (3 * totals[:home_runs])
      average = ratio(totals[:hits], totals[:at_bats])
      obp = ratio(
        totals[:hits] + totals[:walks] + totals[:hit_by_pitch],
        totals[:at_bats] + totals[:walks] + totals[:hit_by_pitch] + totals[:sacrifice_flies]
      )
      slugging = ratio(total_bases, totals[:at_bats])

      common_row(sample_size: totals[:plate_appearances]).merge(
        player_id: player_id,
        team_id: team_id,
        metrics: totals.merge(
          games: lines.map(&:game_id).uniq.length,
          batting_average: average,
          on_base_percentage: obp,
          on_base_percentage_is_approximate: true,
          slugging_percentage: slugging,
          ops: round(obp + slugging)
        )
      )
    end
  end

  def pitching_rows
    pitching_lines.group_by { |line| [ line.player_id, line.team_id ] }.map do |(player_id, team_id), lines|
      totals = sum_fields(lines, %i[outs_recorded batters_faced hits runs earned_runs home_runs walks strikeouts pitches strikes holds saves blown_saves])
      innings = totals[:outs_recorded].div(3) + (totals[:outs_recorded] % 3) / 10.0

      common_row(sample_size: totals[:batters_faced].positive? ? totals[:batters_faced] : totals[:pitches]).merge(
        player_id: player_id,
        team_id: team_id,
        metrics: totals.merge(
          games: lines.map(&:game_id).uniq.length,
          games_started: lines.count(&:starter),
          innings_pitched: innings,
          strike_percentage: ratio(totals[:strikes], totals[:pitches]),
          era: totals[:outs_recorded].positive? ? round(totals[:earned_runs] * 27.0 / totals[:outs_recorded]) : nil,
          whip: totals[:outs_recorded].positive? ? round((totals[:hits] + totals[:walks]) * 3.0 / totals[:outs_recorded]) : nil
        )
      )
    end
  end

  def pitcher_pitch_type_rows
    eligible = pitches.select { |pitch| pitch.pitcher.present? && pitch.pitch_type.present? && players_by_mlb_id.key?(pitch.pitcher) }
    totals_by_pitcher = eligible.group_by(&:pitcher).transform_values(&:length)

    eligible.group_by { |pitch| [ pitch.pitcher, pitch.pitch_type ] }.map do |(mlb_id, pitch_type), grouped|
      player = players_by_mlb_id.fetch(mlb_id)
      swings = grouped.count { |pitch| swing?(pitch) }
      whiffs = grouped.count { |pitch| whiff?(pitch) }
      velocities = values(grouped, :release_speed)
      spin_rates = values(grouped, :release_spin_rate)
      chase_opportunities = grouped.count { |pitch| chase_opportunity?(pitch) }
      chases = grouped.count { |pitch| chase?(pitch) }

      common_row(sample_size: grouped.length).merge(
        player_id: player.id,
        team_id: team_for_pitch_group(grouped, player, pitching: true),
        pitch_type: pitch_type,
        pitch_name: grouped.filter_map(&:pitch_name).first,
        metrics: {
          pitch_count: grouped.length,
          usage_percentage: percent(grouped.length, totals_by_pitcher.fetch(mlb_id)),
          average_velocity: average(velocities),
          maximum_velocity: velocities.max,
          velocity_sample_size: velocities.length,
          average_spin_rate: average(spin_rates),
          spin_sample_size: spin_rates.length,
          average_extension: average(values(grouped, :release_extension)),
          average_horizontal_break: average(values(grouped, :pfx_x)),
          average_vertical_break: average(values(grouped, :pfx_z)),
          zone_percentage: percent(grouped.count { |pitch| pitch.zone.to_i.between?(1, 9) }, grouped.length),
          swings: swings,
          swing_percentage: percent(swings, grouped.length),
          whiffs: whiffs,
          whiff_percentage: percent(whiffs, swings),
          chase_opportunities: chase_opportunities,
          chases: chases,
          chase_percentage: percent(chases, chase_opportunities),
          delta_run_expectancy_per_100: scaled_average(values(grouped, :delta_run_exp), 100)
        }
      )
    end
  end

  def batter_split_rows
    split_rows(:batter, batter_split_dimensions) do |grouped|
      swings = grouped.count { |pitch| swing?(pitch) }
      batted_balls = grouped.select { |pitch| self.class.batted_ball?(pitch) }
      hard_hit = batted_balls.count { |pitch| pitch.launch_speed >= 95 }
      barrels = batted_balls.count { |pitch| pitch.launch_speed_angle == GameBattedBallAnalysis::BARREL_CLASSIFICATION }
      bat_speeds = values(grouped, :bat_speed)
      chase_opportunities = grouped.count { |pitch| chase_opportunity?(pitch) }
      chases = grouped.count { |pitch| chase?(pitch) }

      {
        pitches_seen: grouped.length,
        plate_appearances: plate_appearance_count(grouped),
        swings: swings,
        swing_percentage: percent(swings, grouped.length),
        whiffs: grouped.count { |pitch| whiff?(pitch) },
        whiff_percentage: percent(grouped.count { |pitch| whiff?(pitch) }, swings),
        batted_balls: batted_balls.length,
        exit_velocity_sample_size: batted_balls.length,
        average_exit_velocity: average(values(batted_balls, :launch_speed)),
        maximum_exit_velocity: values(batted_balls, :launch_speed).max,
        barrel_count: barrels,
        barrel_percentage: percent(barrels, batted_balls.length),
        barrel_sample_size: batted_balls.length,
        hard_hit_percentage: percent(hard_hit, batted_balls.length),
        average_bat_speed: average(bat_speeds),
        bat_speed_sample_size: bat_speeds.length,
        average_launch_angle: average(values(batted_balls, :launch_angle)),
        estimated_woba: average(values(grouped, :estimated_woba_using_speedangle)),
        chase_opportunities: chase_opportunities,
        chases: chases,
        chase_percentage: percent(chases, chase_opportunities),
        hits: terminal_event_count(grouped, HIT_EVENTS),
        home_runs: terminal_event_count(grouped, [ "home_run" ]),
        walks: terminal_event_count(grouped, WALK_EVENTS),
        strikeouts: terminal_event_count(grouped, STRIKEOUT_EVENTS)
      }
    end
  end

  def pitcher_split_rows
    split_rows(:pitcher, pitcher_split_dimensions, pitching: true) do |grouped|
      swings = grouped.count { |pitch| swing?(pitch) }
      velocities = values(grouped, :release_speed)
      spin_rates = values(grouped, :release_spin_rate)
      chase_opportunities = grouped.count { |pitch| chase_opportunity?(pitch) }
      chases = grouped.count { |pitch| chase?(pitch) }

      {
        pitch_count: grouped.length,
        batters_faced: plate_appearance_count(grouped),
        zone_percentage: percent(grouped.count { |pitch| pitch.zone.to_i.between?(1, 9) }, grouped.length),
        swings: swings,
        whiffs: grouped.count { |pitch| whiff?(pitch) },
        whiff_percentage: percent(grouped.count { |pitch| whiff?(pitch) }, swings),
        average_velocity: average(velocities),
        maximum_velocity: velocities.max,
        velocity_sample_size: velocities.length,
        average_spin_rate: average(spin_rates),
        spin_sample_size: spin_rates.length,
        chase_opportunities: chase_opportunities,
        chases: chases,
        chase_percentage: percent(chases, chase_opportunities),
        strikeouts: terminal_event_count(grouped, STRIKEOUT_EVENTS),
        walks: terminal_event_count(grouped, WALK_EVENTS),
        delta_run_expectancy_per_100: scaled_average(values(grouped, :delta_run_exp), 100)
      }
    end
  end

  def split_rows(player_field, dimensions, pitching: false)
    output = []
    dimensions.each do |split_type, value_method|
      eligible = pitches.select do |pitch|
        mlb_id = pitch.public_send(player_field)
        mlb_id.present? && players_by_mlb_id.key?(mlb_id) && value_method.call(pitch).present?
      end

      eligible.group_by { |pitch| [ pitch.public_send(player_field), value_method.call(pitch) ] }.each do |(mlb_id, split_value), grouped|
        player = players_by_mlb_id.fetch(mlb_id)
        output << common_row(sample_size: grouped.length).merge(
          player_id: player.id,
          team_id: team_for_pitch_group(grouped, player, pitching: pitching),
          split_type: split_type,
          split_value: split_value,
          metrics: yield(grouped)
        )
      end
    end
    output
  end

  def team_rows
    games.flat_map { |game| [ game.home_team_id, game.away_team_id ] }.uniq.compact.map do |team_id|
      team_games = games.select { |game| game.home_team_id == team_id || game.away_team_id == team_id }
      batting = batting_lines.select { |line| line.team_id == team_id }
      pitching = pitching_lines.select { |line| line.team_id == team_id }
      bat = team_batting_totals(team_id, team_games, batting)
      pit = team_pitching_totals(team_id, team_games, pitching)
      total_bases = bat[:hits] + bat[:doubles] + (2 * bat[:triples]) + (3 * bat[:home_runs])
      average_value = ratio(bat[:hits], bat[:at_bats])
      obp = ratio(
        bat[:hits] + bat[:walks] + bat[:hit_by_pitch],
        bat[:at_bats] + bat[:walks] + bat[:hit_by_pitch] + bat[:sacrifice_flies]
      )
      slugging = ratio(total_bases, bat[:at_bats])
      scores = team_games.filter_map { |game| team_score(game, team_id) }

      common_row(sample_size: team_games.length).merge(
        team_id: team_id,
        metrics: bat.merge(
          games: team_games.length,
          wins: scores.count { |scored, allowed| scored > allowed },
          losses: scores.count { |scored, allowed| scored < allowed },
          ties: scores.count { |scored, allowed| scored == allowed },
          runs_scored: scores.sum(&:first),
          runs_allowed: scores.sum(&:last),
          run_differential: scores.sum { |scored, allowed| scored - allowed },
          batting_average: average_value,
          on_base_percentage: obp,
          on_base_percentage_is_approximate: false,
          slugging_percentage: slugging,
          ops: round(obp + slugging),
          pitching_outs_recorded: pit[:outs_recorded],
          pitching_batters_faced: pit[:batters_faced],
          pitching_hits_allowed: pit[:hits],
          pitching_earned_runs: pit[:earned_runs],
          pitching_walks: pit[:walks],
          pitching_strikeouts: pit[:strikeouts],
          pitching_saves: pit[:saves],
          pitching_quality_starts: pit[:quality_starts],
          era: pit[:outs_recorded].positive? ? round(pit[:earned_runs] * 27.0 / pit[:outs_recorded]) : nil,
          whip: pit[:outs_recorded].positive? ? round((pit[:hits] + pit[:walks]) * 3.0 / pit[:outs_recorded]) : nil
        )
      )
    end
  end

  def common_row(sample_size:)
    {
      metric_date: metric_date,
      source_start_date: metric_date,
      source_end_date: metric_date,
      sample_size: sample_size,
      calculation_version: calculation_version,
      calculated_at: calculated_at,
      source_name: DailyAnalyticsRefresh::SOURCE_NAME,
      created_at: calculated_at,
      updated_at: calculated_at
    }
  end

  def batting_lines
    @batting_lines ||= GamePlayerBattingLine.joins(:game)
      .where(games: { official_date: metric_date, game_type: "R", status: "final" }).select(*BATTING_LINE_COLUMNS).to_a
  end

  def batting_line_official_totals(lines)
    {
      hit_by_pitch: lines.sum { |line| line.raw_data.to_h.dig("stats", "batting", "hitByPitch").to_i },
      sacrifice_flies: lines.sum { |line| line.raw_data.to_h.dig("stats", "batting", "sacFlies").to_i }
    }
  end

  def pitching_lines
    @pitching_lines ||= GamePlayerPitchingLine.joins(:game)
      .where(games: { official_date: metric_date, game_type: "R", status: "final" }).select(*PITCHING_LINE_COLUMNS).to_a
  end

  def games
    @games ||= Game.where(official_date: metric_date, game_type: "R", status: "final")
      .select(:id, :mlb_id, :home_team_id, :away_team_id, :home_score, :away_score, :scheduled_at, :raw_data, :boxscore_raw_data).to_a
  end

  def pitches
    @pitches ||= PitchDatum.where(game_date: metric_date).select(*PITCH_COLUMNS).to_a
  end

  def players_by_mlb_id
    @players_by_mlb_id ||= Player.where(mlb_id: pitches.flat_map { |pitch| [ pitch.pitcher, pitch.batter ] }.compact.uniq).index_by(&:mlb_id)
  end

  def games_by_mlb_id
    @games_by_mlb_id ||= games.index_by(&:mlb_id)
  end

  def team_for_pitch_group(grouped, player, pitching:)
    grouped.each do |pitch|
      game = games_by_mlb_id[pitch.game_pk]
      next unless game

      top = pitch.inning_topbot.to_s.downcase.start_with?("top")
      return pitching ? (top ? game.home_team_id : game.away_team_id) : (top ? game.away_team_id : game.home_team_id)
    end
    player.team_id
  end

  def batter_split_dimensions
    {
      "pitcher_hand" => ->(pitch) { pitch.p_throws.presence&.upcase },
      "pitch_type" => ->(pitch) { pitch.pitch_type.presence },
      "home_away" => ->(pitch) { home_away(pitch, pitching: false) },
      "day_night" => ->(pitch) { day_night(pitch) }
    }
  end

  def pitcher_split_dimensions
    {
      "batter_hand" => ->(pitch) { pitch.stand.presence&.upcase },
      "pitch_type" => ->(pitch) { pitch.pitch_type.presence },
      "home_away" => ->(pitch) { home_away(pitch, pitching: true) },
      "day_night" => ->(pitch) { day_night(pitch) }
    }
  end

  def home_away(pitch, pitching:)
    value = pitch.inning_topbot.to_s.downcase
    return if value.blank?

    top = value.start_with?("top")
    pitching ? (top ? "home" : "away") : (top ? "away" : "home")
  end

  def day_night(pitch)
    game = games_by_mlb_id[pitch.game_pk]
    return if game.nil?

    value = game.raw_data.to_h["dayNight"] || game.raw_data.to_h.dig("gameData", "datetime", "dayNight")
    return value.downcase if %w[day night].include?(value.to_s.downcase)
    return if game.scheduled_at.nil?

    game.scheduled_at.in_time_zone("America/New_York").hour < 17 ? "day" : "night"
  end

  def team_score(game, team_id)
    return if game.home_score.nil? || game.away_score.nil?

    game.home_team_id == team_id ? [ game.home_score, game.away_score ] : [ game.away_score, game.home_score ]
  end

  def team_pitching_totals(team_id, team_games, pitching_lines_for_team)
    fields = %i[outs_recorded batters_faced hits earned_runs walks strikeouts saves quality_starts]
    lines_by_game_id = pitching_lines_for_team.group_by(&:game_id)

    team_games.each_with_object(fields.to_h { |field| [ field, 0 ] }) do |game, totals|
      game_lines = lines_by_game_id.fetch(game.id, [])
      fallback = sum_fields(game_lines, fields - %i[quality_starts]).merge(
        quality_starts: game_lines.count { |line| line.starter? && line.outs_recorded.to_i >= 18 && line.earned_runs.to_i <= 3 }
      )
      official = official_team_pitching_stats(game, team_id)
      game_totals = official.present? ? official_pitching_totals(official, fallback) : fallback

      fields.each { |field| totals[field] += game_totals.fetch(field) }
    end
  end

  def team_batting_totals(team_id, team_games, batting_lines_for_team)
    fields = %i[
      plate_appearances at_bats runs hits doubles triples home_runs walks strikeouts
      hit_by_pitch sacrifice_flies
    ]
    fallback_fields = fields - %i[hit_by_pitch sacrifice_flies]
    lines_by_game_id = batting_lines_for_team.group_by(&:game_id)

    team_games.each_with_object(fields.to_h { |field| [ field, 0 ] }) do |game, totals|
      fallback = sum_fields(lines_by_game_id.fetch(game.id, []), fallback_fields)
        .merge(hit_by_pitch: 0, sacrifice_flies: 0)
      official = official_team_stats(game, team_id, "batting")
      game_totals = official.present? ? official_batting_totals(official, fallback) : fallback

      fields.each { |field| totals[field] += game_totals.fetch(field) }
    end
  end

  def official_team_pitching_stats(game, team_id)
    official_team_stats(game, team_id, "pitching")
  end

  def official_team_stats(game, team_id, group)
    side = game.home_team_id == team_id ? "home" : "away"
    game.boxscore_raw_data.to_h.dig("teams", side, "teamStats", group)
  end

  def official_batting_totals(stats, fallback)
    {
      plate_appearances: integer_or_fallback(stats["plateAppearances"], fallback.fetch(:plate_appearances)),
      at_bats: integer_or_fallback(stats["atBats"], fallback.fetch(:at_bats)),
      runs: integer_or_fallback(stats["runs"], fallback.fetch(:runs)),
      hits: integer_or_fallback(stats["hits"], fallback.fetch(:hits)),
      doubles: integer_or_fallback(stats["doubles"], fallback.fetch(:doubles)),
      triples: integer_or_fallback(stats["triples"], fallback.fetch(:triples)),
      home_runs: integer_or_fallback(stats["homeRuns"], fallback.fetch(:home_runs)),
      walks: integer_or_fallback(stats["baseOnBalls"], fallback.fetch(:walks)),
      strikeouts: integer_or_fallback(stats["strikeOuts"], fallback.fetch(:strikeouts)),
      hit_by_pitch: integer_or_fallback(stats["hitByPitch"], fallback.fetch(:hit_by_pitch)),
      sacrifice_flies: integer_or_fallback(stats["sacFlies"], fallback.fetch(:sacrifice_flies))
    }
  end

  def official_pitching_totals(stats, fallback)
    {
      outs_recorded: innings_to_outs(stats["inningsPitched"]) || fallback.fetch(:outs_recorded),
      batters_faced: integer_or_fallback(stats["battersFaced"], fallback.fetch(:batters_faced)),
      hits: integer_or_fallback(stats["hits"], fallback.fetch(:hits)),
      earned_runs: integer_or_fallback(stats["earnedRuns"], fallback.fetch(:earned_runs)),
      walks: integer_or_fallback(stats["baseOnBalls"], fallback.fetch(:walks)),
      strikeouts: integer_or_fallback(stats["strikeOuts"], fallback.fetch(:strikeouts)),
      saves: integer_or_fallback(stats["saves"], fallback.fetch(:saves)),
      quality_starts: fallback.fetch(:quality_starts)
    }
  end

  def innings_to_outs(value)
    match = /\A(\d+)\.(\d)\z/.match(value.to_s)
    return if match.nil?

    (match[1].to_i * 3) + match[2].to_i.clamp(0, 2)
  end

  def integer_or_fallback(value, fallback)
    Integer(value, exception: false) || fallback
  end

  def sum_fields(records, fields)
    fields.to_h { |field| [ field, records.sum { |record| record.public_send(field).to_i } ] }
  end

  def values(records, field)
    records.filter_map { |record| record.public_send(field)&.to_f }
  end

  def plate_appearance_count(grouped)
    grouped.map { |pitch| [ pitch.game_pk, pitch.at_bat_number ] }.uniq.length
  end

  def terminal_event_count(grouped, event_names)
    grouped.select { |pitch| event_names.include?(pitch.events.to_s.downcase) }
      .map { |pitch| [ pitch.game_pk, pitch.at_bat_number ] }.uniq.length
  end

  def swing?(pitch)
    self.class.swing?(pitch)
  end

  def whiff?(pitch)
    self.class.whiff?(pitch)
  end

  def chase_opportunity?(pitch)
    pitch.zone.present? && !pitch.zone.to_i.between?(1, 9)
  end

  def chase?(pitch)
    chase_opportunity?(pitch) && swing?(pitch)
  end

  def average(numbers)
    return if numbers.empty?

    round(numbers.sum / numbers.length.to_f)
  end

  def scaled_average(numbers, scale)
    value = average(numbers)
    value.nil? ? nil : round(value * scale)
  end

  def ratio(numerator, denominator)
    denominator.to_i.zero? ? 0.0 : round(numerator.to_f / denominator)
  end

  def percent(numerator, denominator)
    round(ratio(numerator, denominator) * 100)
  end

  def round(value)
    value.to_f.round(4)
  end
end
