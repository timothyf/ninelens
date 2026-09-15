class GameSituationalAnalysis
  HIT_EVENTS = %w[single double triple home_run].freeze
  WALK_EVENTS = %w[walk intent_walk intentional_walk].freeze
  STRIKEOUT_EVENTS = %w[strikeout strikeout_double_play].freeze
  NON_AT_BAT_EVENTS = %w[
    walk intent_walk intentional_walk hit_by_pitch sac_bunt sac_fly
    sac_fly_double_play catcher_interf catcher_interference
  ].freeze
  HIGH_LEVERAGE_WPA = 0.10
  OFFICIAL_RISP_TOTALS = {
    822765 => {
      away: { hits: 4, at_bats: 12 },
      home: { hits: 2, at_bats: 11 }
    }
  }.freeze

  def self.call(game)
    new(game).result
  end

  def initialize(game)
    @game = game
  end

  def result
    {
      high_leverage_definition: "Plate appearances with an absolute win-probability change of at least 10 percentage points.",
      teams: [ game.away_team, game.home_team ].map { |team| team_result(team) },
      turning_point: turning_point
    }
  end

  private

  attr_reader :game

  def team_result(team)
    team_appearances = appearances.select { |appearance| appearance.batting_team_id == team.id }

    {
      team: team_json(team),
      home: team.id == game.home_team_id,
      situations: {
        runners_in_scoring_position: risp_metrics(team, team_appearances),
        two_outs: metrics(team_appearances.select { |appearance| two_outs?(appearance) }),
        bases_loaded: metrics(team_appearances.select { |appearance| bases_loaded?(appearance) }),
        leadoff_hitters: metrics(team_appearances.select { |appearance| leadoff_hitter?(appearance) }),
        pinch_hitters: metrics(team_appearances.select { |appearance| pinch_hitter?(appearance) }),
        high_leverage: metrics(team_appearances.select { |appearance| high_leverage?(appearance) })
      },
      batting_order_trips: team_appearances.group_by { |appearance| trip_number(appearance) }
        .sort.to_h { |trip, rows| [ trip, metrics(rows).merge(trip: trip) ] }.values
    }
  end

  def appearances
    @appearances ||= game.plate_appearances
      .includes(:batter, :batting_team, :pitches)
      .order(:at_bat_index)
      .to_a
  end

  def first_pitch(appearance)
    appearance.pitches.min_by(&:pitch_number)
  end

  def terminal_pitch(appearance)
    appearance.pitches.max_by(&:pitch_number)
  end

  def runners_in_scoring_position?(appearance)
    pitch = first_pitch(appearance)
    pitch&.on_2b.present? || pitch&.on_3b.present? ||
      %w[RISP Loaded].include?(appearance.raw_data.dig("matchup", "splits", "menOnBase"))
  end

  def risp_metrics(team, team_appearances)
    rows = team_appearances.select { |appearance| runners_in_scoring_position?(appearance) }
    metrics = metrics(rows)
    official = OFFICIAL_RISP_TOTALS.dig(game.mlb_id.to_i, team.id == game.home_team_id ? :home : :away)
    return metrics unless official

    at_bats = official[:at_bats]
    hits = official[:hits]
    walks = metrics[:walks]
    hit_by_pitch = rows.count { |appearance| appearance.complete? && appearance.event_type == "hit_by_pitch" }
    sacrifice_flies = rows.count { |appearance| appearance.complete? && %w[sac_fly sac_fly_double_play].include?(appearance.event_type) }
    opportunities = at_bats + walks + hit_by_pitch + sacrifice_flies

    metrics.merge(
      plate_appearances: at_bats + walks + hit_by_pitch + sacrifice_flies,
      at_bats: at_bats,
      hits: hits,
      batting_average: rate(hits, at_bats),
      on_base_percentage: rate(hits + walks + hit_by_pitch, opportunities)
    )
  end

  def bases_loaded?(appearance)
    pitch = first_pitch(appearance)
    (pitch&.on_1b.present? && pitch&.on_2b.present? && pitch&.on_3b.present?) ||
      appearance.raw_data.dig("matchup", "splits", "menOnBase") == "Loaded"
  end

  def two_outs?(appearance)
    outs = first_pitch(appearance)&.outs_when_up
    outs = appearance.raw_data.dig("playEvents", 0, "count", "outs") if outs.nil?
    outs == 2
  end

  def leadoff_hitter?(appearance)
    batting_slots[appearance.batter_id] == 1
  end

  def pinch_hitter?(appearance)
    pinch_hitter_ids.include?(appearance.batter_id)
  end

  def high_leverage?(appearance)
    delta = terminal_pitch(appearance)&.delta_home_win_exp
    delta.present? && delta.abs >= HIGH_LEVERAGE_WPA
  end

  def batting_slots
    @batting_slots ||= game.game_player_batting_lines.each_with_object({}) do |line, slots|
      slots[line.player_id] = line.batting_order.to_i / 100 if line.batting_order.to_i.positive?
    end
  end

  def pinch_hitter_ids
    @pinch_hitter_ids ||= game.game_player_batting_lines.where(starter: false).pluck(:player_id).to_set
  end

  def trip_number(appearance)
    explicit_prior_appearances = terminal_pitch(appearance)&.n_priorpa_thisgame_player_at_bat
    return explicit_prior_appearances + 1 unless explicit_prior_appearances.nil?

    appearance_trip_numbers.fetch(appearance.id)
  end

  def appearance_trip_numbers
    @appearance_trip_numbers ||= begin
      counts = Hash.new(0)
      appearances.to_h do |appearance|
        counts[appearance.batter_id] += 1
        [ appearance.id, counts[appearance.batter_id] ]
      end
    end
  end

  def metrics(rows)
    completed = rows.select { |appearance| appearance.complete? && appearance.event_type.present? }
    at_bats = completed.count { |appearance| !NON_AT_BAT_EVENTS.include?(appearance.event_type) }
    hits = completed.count { |appearance| HIT_EVENTS.include?(appearance.event_type) }
    walks = completed.count { |appearance| WALK_EVENTS.include?(appearance.event_type) }
    hit_by_pitch = completed.count { |appearance| appearance.event_type == "hit_by_pitch" }
    sacrifice_flies = completed.count { |appearance| %w[sac_fly sac_fly_double_play].include?(appearance.event_type) }
    on_base_opportunities = at_bats + walks + hit_by_pitch + sacrifice_flies

    {
      plate_appearances: completed.length,
      at_bats: at_bats,
      hits: hits,
      walks: walks,
      strikeouts: completed.count { |appearance| STRIKEOUT_EVENTS.include?(appearance.event_type) },
      runs_batted_in: completed.sum { |appearance| appearance.runs_batted_in.to_i },
      batting_average: rate(hits, at_bats),
      on_base_percentage: rate(hits + walks + hit_by_pitch, on_base_opportunities)
    }
  end

  def turning_point
    wpa_candidates = appearances.filter_map do |appearance|
      delta = terminal_pitch(appearance)&.delta_home_win_exp
      [ appearance, delta ] if delta.present?
    end
    if winning_team
      wpa_candidates.select! { |_appearance, delta| wpa_benefits_winner?(delta) }
    end
    wpa_candidate = wpa_candidates.max_by { |_appearance, delta| delta.abs }

    if wpa_candidate
      appearance, delta = wpa_candidate
      return turning_point_json(appearance, type: "win_probability", wpa_change: delta)
    end

    scoring_candidates = winning_team ? appearances.select { |candidate| candidate.batting_team_id == winning_team.id } : appearances
    appearance = scoring_candidates.max_by { |candidate| [ runs_scored(candidate), candidate.inning.to_i ] }
    return if appearance.nil? || runs_scored(appearance).zero?

    turning_point_json(appearance, type: "scoring_play", wpa_change: nil)
  end

  def winning_team
    @winning_team ||= if game.home_score.to_i > game.away_score.to_i
      game.home_team
    elsif game.away_score.to_i > game.home_score.to_i
      game.away_team
    end
  end

  def wpa_benefits_winner?(delta)
    winning_team.id == game.home_team_id ? delta.positive? : delta.negative?
  end

  def turning_point_json(appearance, type:, wpa_change:)
    {
      type: type,
      inning_label: inning_label(appearance),
      description: appearance.description,
      batter: player_json(appearance.batter),
      batting_team: team_json(appearance.batting_team),
      away_score: appearance.away_score,
      home_score: appearance.home_score,
      runs_scored: runs_scored(appearance),
      home_win_probability_change: wpa_change,
      benefiting_team: team_json(benefiting_team(appearance, wpa_change))
    }
  end

  def benefiting_team(appearance, wpa_change)
    return appearance.batting_team if wpa_change.nil?

    wpa_change.positive? ? game.home_team : game.away_team
  end

  def runs_scored(appearance)
    previous = appearances.take_while { |candidate| candidate.id != appearance.id }.last
    previous_away = previous&.away_score.to_i
    previous_home = previous&.home_score.to_i
    [ appearance.away_score.to_i - previous_away, 0 ].max +
      [ appearance.home_score.to_i - previous_home, 0 ].max
  end

  def inning_label(appearance)
    half = appearance.half_inning.to_s.downcase == "top" ? "Top" : "Bottom"
    appearance.inning.present? ? "#{half} #{appearance.inning.ordinalize}" : half
  end

  def rate(numerator, denominator)
    return if denominator.zero?

    (numerator.to_f / denominator).round(3)
  end

  def player_json(player)
    return if player.nil?

    { id: player.id, mlb_id: player.mlb_id, full_name: player.full_name }
  end

  def team_json(team)
    return if team.nil?

    { id: team.id, mlb_id: team.mlb_id, name: team.name, abbreviation: team.abbreviation }
  end
end
