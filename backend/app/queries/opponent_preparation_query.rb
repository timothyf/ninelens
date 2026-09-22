class OpponentPreparationQuery
  RECENT_GAME_LIMIT = 10
  REPERTOIRE_PITCH_LIMIT = 500
  CHANGE_WINDOW = 100
  SWING_DESCRIPTIONS = DailyAnalyticsCalculator::SWING_DESCRIPTIONS
  WHIFF_DESCRIPTIONS = DailyAnalyticsCalculator::WHIFF_DESCRIPTIONS

  def initialize(team:, upcoming_games:, season:, on: Date.current)
    @team = team
    @upcoming_games = upcoming_games
    @season = season
    @on = on
  end

  def result
    return empty_result if series_games.empty?

    {
      opponent: serialize_team(opponent),
      series: series_games.map { |game| GameSerializer.call(game) },
      roster: roster_status,
      recent_performance: recent_performance,
      expected_lineups: expected_lineups,
      probable_starters: opponent_starters.map { |pitcher| pitcher_report(pitcher) },
      bullpen: bullpen_report
    }
  end

  private

  attr_reader :team, :upcoming_games, :season, :on

  def empty_result
    { opponent: nil, series: [], roster: nil, recent_performance: nil, expected_lineups: [], probable_starters: [], bullpen: empty_bullpen }
  end

  def series_games
    @series_games ||= begin
      first = upcoming_games.first
      if first
        opponent_id = opponent_for(first)&.id
        upcoming_games.take_while { |game| opponent_for(game)&.id == opponent_id }
      else
        []
      end
    end
  end

  def opponent
    @opponent ||= opponent_for(series_games.first)
  end

  def opponent_for(game)
    game.home_team_id == team.id ? game.away_team : game.home_team
  end

  def opponent_starters
    series_games.filter_map do |game|
      game.home_team_id == opponent.id ? game.home_probable_pitcher : game.away_probable_pitcher
    end.uniq(&:id)
  end

  def expected_lineups
    series_games.map do |game|
      entries = game.lineup_entries.includes(:player).where(team_id: opponent.id).order(:batting_order).to_a
      serialized_entries = if entries.any?
        entries.map { |entry| serialize_lineup_entry(entry) }
      else
        projected_lineup(game)
      end
      {
        game_id: game.id,
        official_date: game.official_date,
        status: entries.any? ? "confirmed" : "projected",
        entries: serialized_entries
      }
    end
  end

  def projected_lineup(game)
    prior_game = Game.for_team(opponent)
      .where("official_date < ?", game.official_date)
      .where.not(home_score: nil, away_score: nil)
      .order(official_date: :desc, mlb_id: :desc)
      .first
    return projected_roster_lineup unless prior_game

    prior_game.game_player_batting_lines
      .where(team_id: opponent.id, starter: true)
      .includes(:player)
      .order(:batting_order)
      .limit(9)
      .map { |line| serialize_lineup_player(line.player, line.batting_order.to_i / 100, line.position) }
  end

  def projected_roster_lineup
    roster = opponent.rosters.find_by(season: season)
    return [] unless roster

    roster.players.includes(:profile, player_positions: :position).filter_map do |player|
      position = player.player_positions
        .select { |assignment| assignment.season.nil? || assignment.season == season }
        .sort_by { |assignment| [ assignment.is_primary? ? 0 : 1, assignment.position.sort_order ] }
        .first&.position
      next if position&.position_type == "pitcher"

      serialize_lineup_player(player, nil, position&.abbreviation)
    end.sort_by { |entry| [ entry[:position].to_s, entry[:player][:full_name] ] }.first(9)
  end

  def serialize_lineup_player(player, batting_order, position)
    {
      batting_order: batting_order,
      position: position,
      starter: true,
      player: serialize_player(player),
      bats: player.profile&.bats
    }
  end

  def roster_status
    roster = opponent.rosters.find_by(season: season)
    return nil unless roster

    {
      season: roster.season,
      roster_type: roster.roster_type,
      player_count: roster.roster_players.count,
      last_synced_at: roster.last_synced_at
    }
  end

  def serialize_lineup_entry(entry)
    {
      batting_order: entry.batting_slot || entry.batting_order,
      position: entry.position,
      starter: entry.starter,
      player: serialize_player(entry.player),
      bats: entry.player.profile&.bats
    }
  end

  def recent_performance
    scope = TeamDailyMetric.where(metric_date: Date.new(season, 1, 1)..on)
    calculation_version = scope.order(calculated_at: :desc).pick(:calculation_version)
    rows = scope
      .where(team_id: opponent.id, calculation_version: calculation_version)
      .order(metric_date: :desc)
      .limit(RECENT_GAME_LIMIT)
      .to_a
    return { games: 0, wins: 0, losses: 0, runs_per_game: nil, ops: nil, era: nil } if rows.empty?

    totals = rows.each_with_object(Hash.new(0.0)) do |row, sum|
      %w[games wins losses runs_scored at_bats hits doubles triples home_runs walks hit_by_pitch sacrifice_flies
         pitching_outs_recorded pitching_earned_runs].each { |key| sum[key] += row.metrics[key].to_f }
    end
    games = totals["games"].to_i
    obp_denominator = totals.values_at("at_bats", "walks", "hit_by_pitch", "sacrifice_flies").sum
    total_bases = totals["hits"] + totals["doubles"] + (2 * totals["triples"]) + (3 * totals["home_runs"])
    obp = ratio(totals["hits"] + totals["walks"] + totals["hit_by_pitch"], obp_denominator)
    slugging = ratio(total_bases, totals["at_bats"])

    {
      games: games,
      wins: totals["wins"].to_i,
      losses: totals["losses"].to_i,
      runs_per_game: ratio(totals["runs_scored"], games),
      ops: obp && slugging ? round(obp + slugging) : nil,
      era: totals["pitching_outs_recorded"].positive? ? round(totals["pitching_earned_runs"] * 27 / totals["pitching_outs_recorded"]) : nil
    }
  end

  def pitcher_report(pitcher)
    pitches = PitchDatum
      .where(pitcher: pitcher.mlb_id, game_date: Date.new(season, 1, 1)..on)
      .where.not(pitch_type: nil)
      .includes(:game, :plate_appearance)
      .order(game_date: :desc, game_pk: :desc, at_bat_number: :desc, pitch_number: :desc)
      .limit(REPERTOIRE_PITCH_LIMIT)
      .to_a
    current = pitches.first(CHANGE_WINDOW)
    previous = pitches.drop(CHANGE_WINDOW).first(CHANGE_WINDOW)

    {
      player: serialize_player(pitcher),
      throws: pitches.filter_map(&:p_throws).tally.max_by(&:last)&.first,
      sample_size: pitches.length,
      repertoire: repertoire(pitches),
      handedness_splits: handedness_splits(pitches),
      usage_by_count: usage_by_count(pitches),
      first_pitch_tendencies: first_pitch_tendencies(pitches),
      two_strike_tendencies: two_strike_tendencies(pitches),
      location_zones: location_zones(pitches),
      put_away_pitches: put_away_pitches(pitches),
      times_through_order: times_through_order(pitches),
      hitter_attack_plan: hitter_attack_plan(pitches),
      batter_matchups: batter_matchups(pitcher),
      batter_pitch_type_matchups: batter_pitch_type_matchups(pitcher),
      recent_changes: recent_changes(current, previous),
      evidence: evidence(pitches.first(5))
    }
  end

  def batter_matchups(pitcher)
    rows = matchup_pitches(pitcher)
    rows.group_by(&:batter).sort_by { |_batter, batter_rows| -batter_rows.length }.first(12).map do |batter_id, batter_rows|
      batter = Player.find_by(mlb_id: batter_id)
      matchup_summary(batter, batter_rows)
    end
  end

  def batter_pitch_type_matchups(pitcher)
    rows = matchup_pitches(pitcher)
    rows.group_by { |pitch| [ pitch.batter, pitch.pitch_type ] }.sort_by { |_key, type_rows| -type_rows.length }.first(30).map do |(batter_id, pitch_type), type_rows|
      batter = Player.find_by(mlb_id: batter_id)
      matchup_summary(batter, type_rows).merge(
        pitch_type: pitch_type,
        pitch_name: type_rows.filter_map(&:pitch_name).first || pitch_type
      )
    end
  end

  def matchup_pitches(pitcher)
    @matchup_pitches ||= {}
    @matchup_pitches[pitcher.id] ||= PitchDatum.where(
      pitcher: pitcher.mlb_id,
      game_date: Date.new(season, 1, 1)..on,
      batter: team_batter_mlb_ids
    ).where.not(pitch_type: nil).to_a
  end

  def team_batter_mlb_ids
    @team_batter_mlb_ids ||= begin
      ids = series_games.flat_map { |game| game.lineup_entries.where(team_id: team.id).pluck(:player_id) }
      ids = team.game_player_batting_lines.where(game_id: recent_team_game_ids).pluck(:player_id) if ids.empty?
      Player.where(id: ids).pluck(:mlb_id)
    end
  end

  def recent_team_game_ids
    Game.for_team(team).where("official_date < ?", on).order(official_date: :desc).limit(RECENT_GAME_LIMIT).pluck(:id)
  end

  def matchup_summary(batter, rows)
    appearances = rows.map { |pitch| plate_appearance_key(pitch) }.uniq.length
    swings = rows.count { |pitch| DailyAnalyticsCalculator.swing?(pitch) }
    hits = rows.count { |pitch| pitch.events.to_s.downcase.in?(%w[single double triple home_run]) }
    {
      batter: batter ? serialize_player(batter) : { mlb_id: rows.first.batter, full_name: "Batter #{rows.first.batter}" },
      pitches: rows.length,
      plate_appearances: appearances,
      batting_average: percentage(hits, appearances),
      whiff_rate: percentage(rows.count { |pitch| DailyAnalyticsCalculator.whiff?(pitch) }, swings),
      woba: average(rows.filter_map(&:woba_value)),
      evidence: evidence(rows.first(3))
    }
  end

  def bullpen_report
    games = Game.for_team(opponent).where("official_date < ?", on).where.not(home_score: nil, away_score: nil)
      .order(official_date: :desc).limit(5).to_a
    rows = GamePlayerPitchingLine.where(team_id: opponent.id, game_id: games.map(&:id), starter: false).includes(:player, :game).to_a
    by_player = rows.group_by(&:player)
    {
      games_sampled: games.length,
      pitchers: by_player.map do |player, appearances|
        recent = appearances.max_by { |appearance| appearance.game.official_date }
        {
          player: serialize_player(player),
          appearances: appearances.length,
          pitches: appearances.sum { |appearance| appearance.pitches.to_i },
          outs: appearances.sum { |appearance| appearance.outs_recorded.to_i },
          last_used_on: recent&.game&.official_date,
          days_rest: recent ? (on - recent.game.official_date).to_i : nil,
          available: recent.nil? || (on - recent.game.official_date).to_i >= 1
        }
      end.sort_by { |pitcher| [ pitcher[:available] ? 0 : 1, -pitcher[:pitches] ] }
    }
  end

  def empty_bullpen
    { games_sampled: 0, pitchers: [] }
  end

  def repertoire(pitches)
    pitches.group_by(&:pitch_type).sort_by { |_type, rows| -rows.length }.first(6).map do |pitch_type, rows|
      {
        pitch_type: pitch_type,
        pitch_name: rows.filter_map(&:pitch_name).first || pitch_type,
        count: rows.length,
        usage_percentage: percentage(rows.length, pitches.length),
        average_velocity: average(rows.filter_map(&:release_speed)),
        horizontal_break: average(rows.filter_map { |pitch| pitch.pfx_x && pitch.pfx_x * 12 }),
        vertical_break: average(rows.filter_map { |pitch| pitch.pfx_z && pitch.pfx_z * 12 }),
        evidence: evidence(rows.first(2))
      }
    end
  end

  def handedness_splits(pitches)
    %w[L R].map do |hand|
      rows = pitches.select { |pitch| pitch.stand == hand }
      swings = rows.count { |pitch| DailyAnalyticsCalculator.swing?(pitch) }
      appearances = rows.map { |pitch| [ pitch.game_pk, pitch.at_bat_number ] }.uniq.length
      strikeouts = rows.select { |pitch| DailyAnalyticsCalculator::STRIKEOUT_EVENTS.include?(pitch.events.to_s.downcase) }
        .map { |pitch| [ pitch.game_pk, pitch.at_bat_number ] }.uniq.length
      {
        batter_hand: hand,
        pitches: rows.length,
        plate_appearances: appearances,
        strikeout_rate: percentage(strikeouts, appearances),
        whiff_rate: percentage(rows.count { |pitch| DailyAnalyticsCalculator.whiff?(pitch) }, swings),
        evidence: evidence(rows.first(2))
      }
    end
  end

  def usage_by_count(pitches)
    pitches.group_by { |pitch| count_label(pitch) }.sort_by { |label, _rows| count_sort_key(label) }.map do |count, rows|
      {
        count: count,
        pitches: rows.length,
        percentage: percentage(rows.length, pitches.length),
        repertoire: pitch_mix(rows),
        evidence: evidence(rows.first(2))
      }
    end
  end

  def first_pitch_tendencies(pitches)
    rows = first_pitches(pitches)
    {
      pitches: rows.length,
      repertoire: pitch_mix(rows),
      location_zones: zone_mix(rows),
      evidence: evidence(rows.first(4))
    }
  end

  def two_strike_tendencies(pitches)
    rows = pitches.select { |pitch| pitch.strikes.to_i >= 2 }
    {
      pitches: rows.length,
      repertoire: pitch_mix(rows),
      location_zones: zone_mix(rows),
      evidence: evidence(rows.first(4))
    }
  end

  def location_zones(pitches)
    pitches.group_by { |pitch| pitch.zone.presence || "unknown" }.sort_by { |zone, _rows| zone.to_s }.map do |zone, rows|
      {
        zone: zone,
        label: zone == "unknown" ? "Unknown" : "Zone #{zone}",
        pitches: rows.length,
        percentage: percentage(rows.length, pitches.length),
        evidence: evidence(rows.first(2))
      }
    end
  end

  def put_away_pitches(pitches)
    strikeout_appearances = pitches.group_by { |pitch| plate_appearance_key(pitch) }.values.select do |rows|
      rows.max_by(&:pitch_number)&.events.to_s.downcase.in?(DailyAnalyticsCalculator::STRIKEOUT_EVENTS)
    end
    rows = strikeout_appearances.map { |appearance| appearance.max_by(&:pitch_number) }
    pitches.group_by(&:pitch_type).sort_by { |_type, type_rows| -type_rows.length }.filter_map do |pitch_type, type_rows|
      strikeout_rows = rows.select { |pitch| pitch.pitch_type == pitch_type }
      strikeouts = strikeout_rows.length
      next if strikeouts.zero?

      {
        pitch_type: pitch_type,
        pitch_name: type_rows.filter_map(&:pitch_name).first || pitch_type,
        strikeouts: strikeouts,
        strikeout_rate: percentage(strikeouts, strikeout_appearances.length),
        evidence: evidence(strikeout_rows.first(3))
      }
    end.first(5)
  end

  def times_through_order(pitches)
    appearances = pitches.group_by { |pitch| plate_appearance_key(pitch) }
    appearances.group_by { |_key, rows| rows.max_by(&:pitch_number)&.n_thruorder_pitcher || 1 }.sort_by { |order, _rows| order.to_i }.map do |order, grouped|
      rows = grouped.map { |_key, pitches_for_appearance| pitches_for_appearance.max_by(&:pitch_number) }
      strikeouts = rows.count { |pitch| pitch.events.to_s.downcase.in?(DailyAnalyticsCalculator::STRIKEOUT_EVENTS) }
      {
        order: order.to_i,
        plate_appearances: rows.length,
        strikeouts: strikeouts,
        strikeout_rate: percentage(strikeouts, rows.length),
        woba: average(rows.filter_map(&:woba_value)),
        evidence: evidence(rows.first(3))
      }
    end
  end

  def hitter_attack_plan(pitches)
    plan = []
    first = first_pitch_tendencies(pitches)
    if (pitch = first[:repertoire].max_by { |row| row[:percentage].to_f })
      plan << {
        key: "first_pitch",
        label: "First-pitch plan",
        recommendation: "Expect #{pitch[:pitch_name]} early and be ready to attack it in the zone.",
        rationale: "It is the most frequent first pitch (#{pitch[:percentage]}%).",
        evidence: pitch[:evidence]
      }
    end

    put_away = put_away_pitches(pitches).max_by { |row| row[:strikeout_rate].to_f }
    if put_away
      plan << {
        key: "two_strike",
        label: "Two-strike plan",
        recommendation: "Protect against #{put_away[:pitch_name]} with two strikes and expand only with two strikes.",
        rationale: "It accounts for #{put_away[:strikeout_rate]}% of tracked strikeout appearances.",
        evidence: put_away[:evidence]
      }
    end

    zone = location_zones(pitches).reject { |row| row[:zone] == "unknown" }.max_by { |row| row[:percentage].to_f }
    if zone
      plan << {
        key: "location",
        label: "Location plan",
        recommendation: "Prioritize pitches in #{zone[:label]} and avoid chasing outside that area.",
        rationale: "#{zone[:percentage]}% of tracked pitches were recorded there.",
        evidence: zone[:evidence]
      }
    end
    plan
  end

  def pitch_mix(rows)
    rows.group_by(&:pitch_type).sort_by { |_type, type_rows| -type_rows.length }.first(5).map do |pitch_type, type_rows|
      {
        pitch_type: pitch_type,
        pitch_name: type_rows.filter_map(&:pitch_name).first || pitch_type,
        pitches: type_rows.length,
        percentage: percentage(type_rows.length, rows.length),
        evidence: evidence(type_rows.first(2))
      }
    end
  end

  def zone_mix(rows)
    location_zones(rows)
  end

  def first_pitches(pitches)
    pitches.group_by { |pitch| plate_appearance_key(pitch) }.values.filter_map do |rows|
      rows.min_by(&:pitch_number)
    end
  end

  def count_label(pitch)
    balls = pitch.balls
    strikes = pitch.strikes
    balls.nil? || strikes.nil? ? "unknown" : "#{balls}-#{strikes}"
  end

  def count_sort_key(label)
    label == "unknown" ? [ 99, 99 ] : label.split("-").map(&:to_i)
  end

  def plate_appearance_key(pitch)
    [ pitch.game_pk, pitch.at_bat_number ]
  end

  def recent_changes(current, previous)
    return [] if current.empty? || previous.empty?

    changes = []
    velocity_change = difference(average(current.filter_map(&:release_speed)), average(previous.filter_map(&:release_speed)))
    if velocity_change
      changes << {
        key: "velocity",
        label: "Average velocity",
        change: velocity_change,
        unit: "mph",
        evidence: evidence(current.first(2))
      }
    end

    current.group_by(&:pitch_type).sort_by { |_type, rows| -rows.length }.first(3).each do |pitch_type, rows|
      change = difference(percentage(rows.length, current.length), percentage(previous.count { |pitch| pitch.pitch_type == pitch_type }, previous.length))
      next if change.nil?

      changes << {
        key: "usage_#{pitch_type}",
        label: "#{rows.first.pitch_name || pitch_type} usage",
        change: change,
        unit: "percentage_points",
        evidence: evidence(rows.first(2))
      }
    end
    changes
  end

  def evidence(pitches)
    pitches.filter_map do |pitch|
      next unless pitch.game_id && pitch.plate_appearance_id

      {
        game_id: pitch.game_id,
        game_date: pitch.game_date,
        pitch_id: pitch.id,
        plate_appearance_id: pitch.plate_appearance_id,
        pitch_name: pitch.pitch_name || pitch.pitch_type,
        velocity: pitch.release_speed,
        result: pitch.description
      }
    end
  end

  def serialize_team(value)
    { id: value.id, mlb_id: value.mlb_id, name: value.name, abbreviation: value.abbreviation }
  end

  def serialize_player(value)
    { id: value.id, mlb_id: value.mlb_id, full_name: value.full_name }
  end

  def average(values)
    values.empty? ? nil : round(values.sum.to_f / values.length)
  end

  def ratio(numerator, denominator)
    denominator.to_f.positive? ? numerator.to_f / denominator : nil
  end

  def percentage(numerator, denominator)
    value = ratio(numerator, denominator)
    value && round(value * 100)
  end

  def difference(current, previous)
    current && previous ? round(current - previous) : nil
  end

  def round(value)
    value.to_f.round(2)
  end
end
