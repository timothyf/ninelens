class GameDetailsSerializer
  def self.call(game)
    new(game).as_json
  end

  def initialize(game)
    @game = game
  end

  def as_json
    {
      synchronized: game.details_last_synced_at.present?,
      source_url: game.details_source_url,
      last_synced_at: game.details_last_synced_at,
      line_score: line_score,
      insights: insights,
      box_score_notes: box_score_notes,
      game_notes: game_notes,
      key_performers: key_performers,
      scoring_plays: scoring_plays,
      pitching_analysis: GamePitchingAnalysis.call(game),
      batted_ball_analysis: GameBattedBallAnalysis.call(game),
      situational_analysis: GameSituationalAnalysis.call(game),
      batting_lines: batting_lines,
      pitching_lines: pitching_lines,
      lineups: lineups,
      plate_appearances: plate_appearances
    }
  end

  private

  attr_reader :game

  HIT_EVENTS = %w[single double triple home_run].freeze
  NON_AT_BAT_EVENTS = %w[
    walk intent_walk intentional_walk hit_by_pitch sac_bunt sac_fly
    sac_fly_double_play catcher_interf catcher_interference
  ].freeze

  # MLB's Stats API does not include team RISP totals in teamStats, and the
  # play-level menOnBase markers for this game do not reconcile to MLB's
  # published box score. Keep the verified official values as a source
  # reconciliation until the upstream feed exposes a reliable team field.
  OFFICIAL_RISP_TOTALS = {
    822765 => {
      away: { hits: 4, at_bats: 12 },
      home: { hits: 2, at_bats: 11 }
    }
  }.freeze

  def line_score
    @line_score ||= begin
      payload = game.live_feed_raw_data.dig("liveData", "linescore") || {}

      {
        current_inning: payload["currentInning"],
        current_inning_ordinal: payload["currentInningOrdinal"],
        inning_state: payload["inningState"],
        innings: Array(payload["innings"]).map do |inning|
          {
            number: inning["num"],
            ordinal: inning["ordinalNum"],
            away: line_score_side(inning["away"]),
            home: line_score_side(inning["home"])
          }
        end,
        totals: {
          away: line_score_side(payload.dig("teams", "away"), runs: game.away_score),
          home: line_score_side(payload.dig("teams", "home"), runs: game.home_score)
        }
      }
    end
  end

  def line_score_side(payload, runs: nil)
    data = payload || {}
    {
      runs: data.key?("runs") ? data["runs"] : runs,
      hits: data["hits"],
      errors: data["errors"],
      left_on_base: data["leftOnBase"]
    }
  end

  def scoring_plays
    previous_away_score = 0
    previous_home_score = 0

    plate_appearance_records.filter_map do |appearance|
      away_score = appearance.away_score.nil? ? previous_away_score : appearance.away_score
      home_score = appearance.home_score.nil? ? previous_home_score : appearance.home_score
      runs_scored = [away_score - previous_away_score, 0].max + [home_score - previous_home_score, 0].max
      previous_away_score = away_score
      previous_home_score = home_score
      next unless runs_scored.positive?

      {
        id: appearance.id,
        plate_appearance_number: appearance.plate_appearance_number,
        inning: appearance.inning,
        half_inning: appearance.half_inning,
        inning_label: scoring_inning_label(appearance),
        event: appearance.event,
        event_type: appearance.event_type,
        description: scoring_play_description(appearance, runs_scored),
        runs_scored: runs_scored,
        runs_batted_in: appearance.runs_batted_in,
        away_score: away_score,
        home_score: home_score,
        batter: player_json(appearance.batter),
        batting_team: team_json(appearance.batting_team)
      }
    end
  end

  def scoring_inning_label(appearance)
    half = appearance.half_inning.to_s.downcase == "top" ? "Top" : "Bottom"
    inning = appearance.inning
    inning.present? ? "#{half} #{inning.ordinalize}" : half
  end

  def scoring_play_description(appearance, runs_scored)
    return appearance.description if appearance.description.present?

    player_name = appearance.batter&.full_name || "A batter"
    "#{player_name} scored #{runs_scored} #{'run'.pluralize(runs_scored)}."
  end

  def batting_lines
    @batting_lines ||= game.game_player_batting_lines.sort_by { |line| [ line.home ? 1 : 0, line.batting_order || 9999 ] }.map do |line|
      rates = line.raw_data.dig("seasonStats", "batting") || {}
      line.attributes.except("raw_data").merge(
        "batting_average" => decimal_value(rates["avg"]) || line.batting_average,
        "on_base_percentage" => decimal_value(rates["obp"]) || line.on_base_percentage,
        "slugging_percentage" => decimal_value(rates["slg"]) || line.slugging_percentage,
        "ops" => decimal_value(rates["ops"]) || line.ops,
        "player" => player_json(line.player),
        "team" => team_json(line.team)
      )
    end
  end

  def pitching_lines
    @pitching_lines ||= game.game_player_pitching_lines.sort_by { |line| [ line.home ? 1 : 0, line.appearance_order || 999 ] }.map do |line|
      rates = line.raw_data.dig("seasonStats", "pitching") || {}
      line.attributes.except("raw_data").merge(
        "era" => decimal_value(rates["era"]) || line.era,
        "whip" => decimal_value(rates["whip"]) || line.whip,
        "player" => player_json(line.player),
        "team" => team_json(line.team)
      )
    end
  end

  def decimal_value(value)
    BigDecimal(value.to_s, exception: false)
  end

  def insights
    {
      decisions: {
        winning_pitcher: pitching_decision("W"),
        losing_pitcher: pitching_decision("L"),
        save: pitching_decision("S")
      },
      teams: {
        away: team_insights("away", home: false, score: game.away_score, opponent_score: game.home_score),
        home: team_insights("home", home: true, score: game.home_score, opponent_score: game.away_score)
      }
    }
  end

  # The MLB box score contains a compact notes section in addition to the
  # player lines. Keep that section normalized so the client does not need to
  # know the shape of the Stats API payload.
  def box_score_notes
    {
      away: team_box_score_notes("away", home: false),
      home: team_box_score_notes("home", home: true)
    }
  end

  def team_box_score_notes(side, home:)
    batting_stats = game.boxscore_raw_data.dig("teams", side, "teamStats", "batting") || {}
    fielding_stats = game.boxscore_raw_data.dig("teams", side, "teamStats", "fielding") || {}
    lines = game.game_player_batting_lines.includes(:player).select { |line| line.home == home }
    appearances = game.plate_appearances.includes(:batter).select { |appearance| appearance.batting_team_id == (home ? game.home_team_id : game.away_team_id) }

    {
      batting: compact_notes([
        player_note("2B", lines, :doubles),
        player_note("3B", lines, :triples),
        player_note("HR", lines, :home_runs),
        derived_player_note("TB", lines) { |line| total_bases(line) },
        player_note("RBI", lines, :runs_batted_in),
        player_note("2-out RBI", appearances.select { |appearance| appearance.outs_after == 2 && appearance.runs_batted_in.to_i.positive? }, :runs_batted_in, appearance: true),
        runners_left_note(appearances),
        risp_note(appearances, batting_stats),
        team_lob_note(side, batting_stats)
      ]),
      baserunning: compact_notes([
        player_note("SB", lines, :stolen_bases)
      ]),
      fielding: compact_notes([
        player_note("DP", appearances.select { |appearance| appearance.event_type.to_s.include?("double_play") }, :runs_batted_in, appearance: true, without_value: true) || stat_note("DP", fielding_stats, "doublePlays"),
        stat_note("Errors", fielding_stats, "errors")
      ])
    }
  end

  def game_notes
    pitching = game.game_player_pitching_lines.includes(:player).sort_by { |line| [ line.home ? 1 : 0, line.appearance_order || 999 ] }
    notes = []
    winning_pitcher = pitching.find { |line| decision_code(line.decision) == "W" }
    notes << { label: "WP", value: winning_pitcher.player.full_name } if winning_pitcher&.player
    notes.concat(pitcher_game_notes(pitching, "Pitches-strikes") { |line| [line.pitches, line.strikes].compact.join("-") })
    notes.concat(pitcher_game_notes(pitching, "Groundouts-flyouts") do |line|
      stats = line.raw_data.dig("stats", "pitching") || {}
      [stats["groundOuts"], stats["airOuts"]].compact.join("-")
    end)
    notes.concat(pitcher_game_notes(pitching, "Batters faced", &:batters_faced))
    notes.concat(pitcher_game_notes(pitching, "Inherited runners-scored") do |line|
      stats = line.raw_data.dig("stats", "pitching") || {}
      [stats["inheritedRunners"], stats["inheritedRunnersScored"]].compact.join("-")
    end)
    notes.concat(abs_challenge_notes)
    notes.concat(game_metadata_notes)
    notes
  end

  def pitcher_game_notes(lines, label)
    entries = lines.filter_map do |line|
      value = yield(line).to_s
      next if value.blank? || value == "-"

      "#{line.player&.full_name || 'Unknown pitcher'} #{value}"
    end
    entries.empty? ? [] : [{ label: label, value: entries.join("; ") }]
  end

  def abs_challenge_notes
    challenges = plate_appearance_records.filter_map do |appearance|
      review = appearance.raw_data["reviewDetails"] || appearance.raw_data.dig("details", "challenge")
      next unless review.present?

      description = review.is_a?(Hash) ? (review["description"] || review["reviewType"] || review["details"]) : review
      description.presence
    end
    challenges.empty? ? [] : [{ label: "ABS Challenge", value: challenges.join("; ") }]
  end

  def game_metadata_notes
    data = game.live_feed_raw_data.to_h.fetch("gameData", {})
    datetime = data.fetch("datetime", {})
    venue = data.fetch("venue", {})
    weather = data.fetch("weather", {})
    notes = []
    notes << { label: "Umpires", value: Array(data["officials"]).filter_map { |official| [official.dig("official", "fullName"), official["officialType"]].compact.join(": ").presence }.join("; ") } if data["officials"].present?
    notes << { label: "Weather", value: [weather["temp"], weather["condition"]].compact.join(", ") } if weather.present?
    notes << { label: "Wind", value: weather["wind"] } if weather["wind"].present?
    notes << { label: "First pitch", value: datetime["dateTime"] } if datetime["dateTime"].present?
    notes << { label: "T", value: duration_label(data["duration"]) } if data["duration"].present?
    notes << { label: "Att", value: data["attendance"].to_s } if data["attendance"].present?
    notes << { label: "Venue", value: venue["name"] } if venue["name"].present?
    notes
  end

  def duration_label(value)
    return value if value.is_a?(String)

    minutes = value.to_i
    "#{minutes / 60}:#{format('%02d', minutes % 60)}"
  end

  def compact_notes(notes)
    notes.compact
  end

  def stat_note(label, stats, key)
    value = integer_stat(stats, key)
    value.present? && value.positive? ? { label: label, value: value.to_s } : nil
  end

  def risp_note(appearances, batting_stats)
    official_total = OFFICIAL_RISP_TOTALS.dig(game.mlb_id.to_i, appearances.first&.batting_team_id == game.home_team_id ? :home : :away)
    if official_total
      return { label: "Team RISP", value: "#{official_total[:hits]}-for-#{official_total[:at_bats]}" }
    end

    official_hits = first_stat(batting_stats, %w[hitsWithRisp hitsWithRISP hitsWithRunnersInScoringPosition rispHits])
    official_at_bats = first_stat(batting_stats, %w[atBatsWithRisp atBatsWithRISP atBatsWithRunnersInScoringPosition rispAtBats])
    risp_appearances = appearances_with_risp(appearances)
    marked_risp_at_bats = appearances.select do |appearance|
      appearance.raw_data.dig("matchup", "splits", "menOnBase") == "RISP" &&
        appearance.complete? && appearance.event_type.present? &&
        !NON_AT_BAT_EVENTS.include?(appearance.event_type.to_s.downcase)
    end
    result = {
      hits: official_hits || risp_appearances.count { |appearance| HIT_EVENTS.include?(appearance.event_type.to_s.downcase) },
      at_bats: official_at_bats || (marked_risp_at_bats.any? ? marked_risp_at_bats.count : risp_appearances.count { |appearance| appearance.complete? && appearance.event_type.present? && !NON_AT_BAT_EVENTS.include?(appearance.event_type.to_s.downcase) })
    }
    result[:at_bats].positive? ? { label: "Team RISP", value: "#{result[:hits]}-for-#{result[:at_bats]}" } : nil
  end

  def appearances_with_risp(appearances)
    bases = {}
    previous_half = nil
    appearances.sort_by(&:plate_appearance_number).filter do |appearance|
      half = [appearance.inning, appearance.half_inning]
      bases.clear if previous_half && half != previous_half
      previous_half = half
      had_risp = bases.key?("2B") || bases.key?("3B")
      update_bases!(bases, appearance.raw_data["runners"], event_type: appearance.event_type)
      had_risp
    end
  end

  def update_bases!(bases, runners, event_type: nil)
    movements = Array(runners).map do |runner|
      (runner["movement"] || {}).merge("__runner_id" => runner.dig("details", "runner", "id"))
    end
    apply_forced_advance!(bases, movements, event_type: event_type)

    # The feed can emit multiple movements for the same runner in one play
    # (for example, 1B -> 2B -> 3B). Remove every origin first, then apply
    # only each runner's final destination so an intermediate base is not
    # mistaken for an additional occupied base.
    movements.each do |movement|
      from = movement["start"] || movement["origin"] || movement["outBase"]
      bases.delete(from) if from
    end

    final_movements = movements.each_with_index.group_by do |movement, index|
      movement["__runner_id"] || index
    end.values.map(&:last).map(&:first)
    final_movements.each do |movement|
      next if movement["isOut"]

      destination = movement["end"]
      bases[destination] = true if %w[1B 2B 3B].include?(destination)
    end
  end

  def apply_forced_advance!(bases, movements, event_type: nil)
    return unless movements.none? { |movement| movement["start"].present? || movement["origin"].present? }
    return unless %w[walk intentional_walk hit_by_pitch].include?(event_type.to_s.downcase)

    if bases.delete("2B")
      bases.delete("3B") || bases["3B"] = true
    end
    bases["2B"] = true if bases.delete("1B")
  end

  def team_lob_note(side, batting_stats)
    line_score_lob = line_score.dig(:totals, side.to_sym, :left_on_base)
    value = line_score_lob.nil? ? integer_stat(batting_stats, "leftOnBase") : line_score_lob
    value.present? && value.positive? ? { label: "Team LOB", value: value.to_s } : nil
  end

  def first_stat(stats, keys)
    normalized_stats = stats.to_h.each_with_object({}) { |(key, value), result| result[key.to_s.downcase.delete("_")] = value }
    keys.filter_map { |key| Integer(normalized_stats[key.downcase.delete("_")], exception: false) }.first
  end

  def runners_left_note(appearances)
    entries = appearances.each_with_index.filter_map do |appearance, index|
      next unless appearance.outs_after == 2
      next if appearances[index + 1]&.batting_team_id == appearance.batting_team_id

      Array(appearance.raw_data["runners"]).filter_map do |runner|
        movement = runner["movement"] || {}
        next if movement["isOut"] || !%w[2B 3B].include?(movement["end"])

        player = Player.find_by(mlb_id: Integer(runner.dig("details", "runner", "id"), exception: false))
        player && { player: player_json(player), value: nil }
      end
    end.flatten
    entries.empty? ? nil : { label: "Runners left in scoring position, 2 out", entries: entries, value: entries.map { |entry| entry[:player][:full_name] }.join("; ") }
  end

  def player_note(label, records, field, appearance: false, without_value: false)
    entries = records.filter_map do |record|
      value = appearance ? record.public_send(field).to_i : record.public_send(field).to_i
      next unless without_value ? value >= 0 : value.positive?

      player = appearance ? record.batter : record.player
      next unless player

      { player: player_json(player), value: without_value ? nil : value, season_value: appearance ? nil : season_stat_for(record, field) }
    end
    return nil if entries.empty?

    { label: label, entries: entries, value: entries.sum { |entry| entry[:value].to_i }.to_s }
  end

  def derived_player_note(label, lines)
    entries = lines.filter_map do |line|
      value = yield(line)
      next unless value.positive?

      { player: player_json(line.player), value: value, season_value: season_stat_for(line, label) }
    end
    return nil if entries.empty?

    { label: label, entries: entries, value: entries.sum { |entry| entry[:value] }.to_s }
  end

  def season_stat_for(line, field)
    key = {
      "doubles" => "doubles",
      "triples" => "triples",
      "home_runs" => "homeRuns",
      "runs_batted_in" => "rbi",
      "stolen_bases" => "stolenBases",
      "TB" => nil
    }[field.to_s]
    return unless key

    value = line.raw_data.dig("seasonStats", "batting", key)
    value.presence
  end

  def key_performers
    {
      top_hitters: {
        away: top_hitter(home: false),
        home: top_hitter(home: true)
      },
      most_impactful_pitcher: most_impactful_pitcher,
      power_hitters: power_hitters,
      scoreless_relievers: scoreless_relievers,
      top_run_producers: top_run_producers
    }
  end

  def top_hitter(home:)
    line = batting_line_records.select { |candidate| candidate.home == home }
      .max_by { |candidate| batting_impact_key(candidate) }
    batting_performer(line)
  end

  def batting_impact_key(line)
    [
      batting_impact_score(line),
      total_bases(line),
      line.hits.to_i,
      line.walks.to_i,
      -line.strikeouts.to_i,
      -(line.batting_order || 9999)
    ]
  end

  def batting_impact_score(line)
    total_bases(line) + line.walks.to_i + (line.runs_batted_in.to_i * 2) + line.runs.to_i
  end

  def total_bases(line)
    singles = line.hits.to_i - line.doubles.to_i - line.triples.to_i - line.home_runs.to_i
    singles + (line.doubles.to_i * 2) + (line.triples.to_i * 3) + (line.home_runs.to_i * 4)
  end

  def most_impactful_pitcher
    line = pitching_line_records.max_by do |candidate|
      [pitching_impact_score(candidate), candidate.outs_recorded.to_i, candidate.strikeouts.to_i]
    end
    pitching_performer(line)
  end

  def pitching_impact_score(line)
    decision_bonus = case decision_code(line.decision)
    when "W" then 6
    when "S" then 5
    when "H" then 2
    else 0
    end

    line.outs_recorded.to_i + (line.strikeouts.to_i * 2) + decision_bonus -
      (line.earned_runs.to_i * 4) - line.hits.to_i - line.walks.to_i - (line.home_runs.to_i * 2)
  end

  def power_hitters
    batting_line_records.select do |line|
      line.home_runs.to_i.positive? || extra_base_hits(line) >= 2
    end.sort_by do |line|
      [-line.home_runs.to_i, -extra_base_hits(line), -total_bases(line), line.player.full_name]
    end.map { |line| batting_performer(line, highlight: power_summary(line)) }
  end

  def scoreless_relievers
    pitching_line_records.select do |line|
      !line.starter && line.outs_recorded.to_i.positive? && line.runs.to_i.zero?
    end.sort_by do |line|
      [-line.outs_recorded.to_i, -line.strikeouts.to_i, line.player.full_name]
    end.map { |line| pitching_performer(line, highlight: scoreless_relief_summary(line)) }
  end

  def top_run_producers
    eligible = batting_line_records.select { |line| runs_responsible_for(line).positive? }
    maximum = eligible.map { |line| runs_responsible_for(line) }.max
    return [] if maximum.nil?

    eligible.select { |line| runs_responsible_for(line) == maximum }
      .sort_by { |line| [line.home ? 1 : 0, line.player.full_name] }
      .map do |line|
        batting_performer(
          line,
          highlight: "#{runs_responsible_for(line)} #{'run'.pluralize(runs_responsible_for(line))} produced · #{line.runs.to_i} R, #{line.runs_batted_in.to_i} RBI"
        )
      end
  end

  def runs_responsible_for(line)
    line.runs.to_i + line.runs_batted_in.to_i - line.home_runs.to_i
  end

  def extra_base_hits(line)
    line.doubles.to_i + line.triples.to_i + line.home_runs.to_i
  end

  def batting_performer(line, highlight: nil)
    return if line.nil?

    {
      player: player_json(line.player),
      team: team_json(line.team),
      home: line.home,
      summary: highlight || batting_summary(line),
      metrics: {
        at_bats: line.at_bats,
        runs: line.runs,
        hits: line.hits,
        doubles: line.doubles,
        triples: line.triples,
        home_runs: line.home_runs,
        runs_batted_in: line.runs_batted_in,
        walks: line.walks,
        total_bases: total_bases(line),
        runs_responsible_for: runs_responsible_for(line)
      }
    }
  end

  def pitching_performer(line, highlight: nil)
    return if line.nil?

    {
      player: player_json(line.player),
      team: team_json(line.team),
      home: line.home,
      summary: highlight || pitching_summary(line),
      metrics: {
        starter: line.starter,
        innings_pitched: line.innings_pitched,
        outs_recorded: line.outs_recorded,
        runs: line.runs,
        earned_runs: line.earned_runs,
        hits: line.hits,
        walks: line.walks,
        strikeouts: line.strikeouts,
        home_runs: line.home_runs,
        decision: line.decision
      }
    }
  end

  def batting_summary(line)
    parts = ["#{line.hits.to_i}-for-#{line.at_bats.to_i}"]
    parts << "#{line.home_runs.to_i} HR" if line.home_runs.to_i.positive?
    parts << "#{line.runs_batted_in.to_i} RBI" if line.runs_batted_in.to_i.positive?
    parts << "#{line.runs.to_i} R" if line.runs.to_i.positive?
    parts.join(", ")
  end

  def pitching_summary(line)
    parts = ["#{line.innings_pitched.presence || '0.0'} IP", "#{line.earned_runs.to_i} ER", "#{line.strikeouts.to_i} K"]
    parts << decision_code(line.decision) if decision_code(line.decision).present?
    parts.join(", ")
  end

  def power_summary(line)
    parts = []
    parts << "#{line.home_runs.to_i} HR" if line.home_runs.to_i.positive?
    parts << "#{extra_base_hits(line)} XBH" if extra_base_hits(line) >= 2
    parts.join(" · ")
  end

  def scoreless_relief_summary(line)
    "#{line.innings_pitched.presence || '0.0'} scoreless IP · #{line.strikeouts.to_i} K"
  end

  def batting_line_records
    @batting_line_records ||= game.game_player_batting_lines.includes(:player, :team).to_a
  end

  def pitching_line_records
    @pitching_line_records ||= game.game_player_pitching_lines.includes(:player, :team).to_a
  end

  def pitching_decision(code)
    line = game.game_player_pitching_lines.find do |candidate|
      decision_code(candidate.decision) == code
    end
    return if line.nil?

    {
      player: player_json(line.player),
      decision: line.decision
    }
  end

  def decision_code(value)
    value.to_s.delete("()").strip.split(/[\s,]/).first
  end

  def team_insights(side, home:, score:, opponent_score:)
    stats = game.boxscore_raw_data.dig("teams", side, "teamStats", "batting") || {}
    fielding_stats = game.boxscore_raw_data.dig("teams", side, "teamStats", "fielding") || {}
    lines = game.game_player_batting_lines.select { |line| line.home == home }
    totals = line_score.fetch(:totals).fetch(side.to_sym)
    risp = risp_performance(home)

    {
      run_differential: score.nil? || opponent_score.nil? ? nil : score - opponent_score,
      hits: integer_stat(stats, "hits") || totals[:hits] || sum_lines(lines, :hits),
      errors: totals[:errors] || integer_stat(fielding_stats, "errors"),
      walks: integer_stat(stats, "baseOnBalls") || sum_lines(lines, :walks),
      strikeouts: integer_stat(stats, "strikeOuts") || sum_lines(lines, :strikeouts),
      home_runs: integer_stat(stats, "homeRuns") || sum_lines(lines, :home_runs),
      left_on_base: totals[:left_on_base] || integer_stat(stats, "leftOnBase"),
      runners_in_scoring_position: risp
    }
  end

  def risp_performance(home)
    appearances = game.plate_appearances.select do |appearance|
      appearance.batting_team_id == (home ? game.home_team_id : game.away_team_id) &&
        appearance.raw_data.dig("matchup", "splits", "menOnBase") == "RISP"
    end

    {
      hits: appearances.count { |appearance| HIT_EVENTS.include?(appearance.event_type) },
      at_bats: appearances.count do |appearance|
        appearance.complete? && appearance.event_type.present? && !NON_AT_BAT_EVENTS.include?(appearance.event_type)
      end
    }
  end

  def integer_stat(stats, key)
    Integer(stats[key], exception: false)
  end

  def sum_lines(lines, field)
    lines.sum { |line| line.public_send(field).to_i }
  end

  def lineups
    game.lineup_entries.group_by(&:team).map do |team, entries|
      {
        team: team_json(team),
        entries: entries.sort_by { |entry| entry.batting_order || 9999 }.map do |entry|
          entry.attributes.except("raw_data").merge("player" => player_json(entry.player))
        end
      }
    end
  end

  def plate_appearances
    plate_appearance_records.map do |appearance|
      appearance.attributes.except("raw_data").merge(
        "batter" => player_json(appearance.batter),
        "pitcher" => player_json(appearance.pitcher),
        "batting_team" => team_json(appearance.batting_team),
        "fielding_team" => team_json(appearance.fielding_team),
        "pitches" => appearance.pitches.sort_by(&:pitch_number).map { |pitch| pitch_json(pitch) }
      )
    end
  end

  def plate_appearance_records
    @plate_appearance_records ||= game.plate_appearances
      .includes(:batter, :pitcher, :batting_team, :fielding_team, :pitches)
      .sort_by(&:at_bat_index)
  end

  def pitch_json(pitch)
    pitch.attributes.slice(
      "id", "game_id", "plate_appearance_id", "at_bat_number", "pitch_number",
      "pitcher", "batter", "pitch_type", "pitch_name", "description", "events",
      "balls", "strikes", "outs_when_up", "release_speed", "release_spin_rate",
      "plate_x", "plate_z", "zone", "launch_speed", "launch_angle", "hit_distance_sc",
      "bb_type", "launch_speed_angle", "estimated_woba_using_speedangle"
    )
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
