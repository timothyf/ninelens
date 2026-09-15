class MlbTotalsReconciliation
  TEAM_STAT_DEFINITIONS = {
    "batting" => [
      { key: "atBats", aliases: %w[atBats AB] },
      { key: "runs", aliases: %w[runs R] },
      { key: "hits", aliases: %w[hits H] },
      { key: "homeRuns", aliases: %w[homeRuns HR] },
      { key: "rbi", aliases: %w[rbi RBI] },
      { key: "baseOnBalls", aliases: %w[baseOnBalls BB] },
      { key: "strikeOuts", aliases: %w[strikeOuts SO] }
    ],
    "pitching" => [
      { key: "inningsPitched", aliases: %w[inningsPitched IP], innings: true },
      { key: "hits", aliases: %w[hits H] },
      { key: "runs", aliases: %w[runs R] },
      { key: "earnedRuns", aliases: %w[earnedRuns ER] },
      { key: "homeRuns", aliases: %w[homeRuns HR] },
      { key: "baseOnBalls", aliases: %w[baseOnBalls BB] },
      { key: "strikeOuts", aliases: %w[strikeOuts SO] }
    ]
  }.freeze
  DEFAULT_TEAM_MLB_IDS = [ 116, 119, 147 ].freeze
  DEFAULT_PLAYER_SELECTIONS = [
    { "mlb_id" => 682_985, "category" => "batting" },
    { "mlb_id" => 592_450, "category" => "batting" },
    { "mlb_id" => 660_271, "category" => "batting" },
    { "mlb_id" => 669_373, "category" => "pitching" }
  ].freeze

  def self.call(season: nil)
    new(season:).call
  end

  def initialize(season: nil)
    @season = season || PlayerSeasonStat.maximum(:season) || ApplicationCalendar.current_date.year
  end

  def call
    [ team_totals_check("batting"), team_totals_check("pitching"), standings_check, player_totals_check ]
  end

  private

  attr_reader :season

  def team_totals_check(category)
    official = MlbTeamStatsDownloader.call(season:, category:)
    mismatches = selected_teams.filter_map do |team|
      next if live_game_today?(team)

      compare_stat_definitions(
        local_values: team_stat_values(team, category),
        official_values: official[team.mlb_id] || {},
        definitions: TEAM_STAT_DEFINITIONS.fetch(category),
        label: team.name
      )
    end.flatten

    build_check(
      id: "official_#{category}_team_totals",
      name: "Official MLB #{category} team totals agree",
      affected_count: mismatches.length,
      examples: mismatches,
      recommendation: "Re-synchronize finalized game details for the affected teams, then re-run this reconciliation."
    )
  rescue StandardError => error
    unavailable_check("official_#{category}_team_totals", "Official MLB #{category} team totals are available", error)
  end

  def standings_check
    official = MlbStandingsDownloader.call(season:)
    mismatches = selected_teams.filter_map do |team|
      official_row = official[team.mlb_id]
      next "#{team.name}: not returned by MLB" unless official_row

      local = local_record(team)
      next if local[:wins] == official_row["wins"].to_i && local[:losses] == official_row["losses"].to_i

      "#{team.name}: local #{local[:wins]}-#{local[:losses]} vs MLB #{official_row["wins"]}-#{official_row["losses"]}"
    end

    build_check(
      id: "official_standings",
      name: "Official MLB standings agree",
      affected_count: mismatches.length,
      examples: mismatches,
      recommendation: "Synchronize schedules and game details for the affected teams, then re-run this reconciliation."
    )
  rescue StandardError => error
    unavailable_check("official_standings", "Official MLB standings are available", error)
  end

  def player_totals_check
    mismatches = player_selections.filter_map do |selection|
      player = Player.find_by(mlb_id: selection.fetch("mlb_id"))
      next unless player

      category = selection.fetch("category")
      official = MlbPlayerSeasonTotalsDownloader.call(mlb_id: player.mlb_id, season:, category:)
      compare_stat_definitions(
        local_rows: player_stat_rows(player, category),
        official_values: official,
        definitions: TEAM_STAT_DEFINITIONS.fetch(category),
        label: player.full_name,
        prefer_combined: true
      )
    end.flatten

    build_check(
      id: "official_selected_player_totals",
      name: "Official MLB selected player totals agree",
      affected_count: mismatches.length,
      examples: mismatches,
      recommendation: "Re-import player season statistics for the affected players, then re-run this reconciliation."
    )
  rescue StandardError => error
    unavailable_check("official_selected_player_totals", "Official MLB selected player totals are available", error)
  end

  def compare_stat_definitions(local_rows: [], local_values: nil, official_values:, definitions:, label:, prefer_combined: false)
    definitions.filter_map do |definition|
      official_value = official_values[definition.fetch(:key)]
      next if official_value.blank?

      local_value = stat_value(local_rows, definition, prefer_combined:, local_values:)
      next if equal_stat_values?(local_value, official_value, definition)

      "#{label} #{definition.fetch(:key)}: local #{display_value(local_value, definition)} vs MLB #{official_value}"
    end
  end

  def team_stat_values(team, category)
    lines = team_game_lines(team, category)

    case category
    when "batting"
      {
        "atBats" => lines.sum { |line| line.at_bats.to_i },
        "runs" => lines.sum { |line| line.runs.to_i },
        "hits" => lines.sum { |line| line.hits.to_i },
        "homeRuns" => lines.sum { |line| line.home_runs.to_i },
        "rbi" => lines.sum { |line| line.runs_batted_in.to_i },
        "baseOnBalls" => lines.sum { |line| line.walks.to_i },
        "strikeOuts" => lines.sum { |line| line.strikeouts.to_i }
      }
    when "pitching"
      {
        "inningsPitched" => lines.sum { |line| line.outs_recorded.to_i },
        "hits" => lines.sum { |line| line.hits.to_i },
        "runs" => lines.sum { |line| line.runs.to_i },
        "earnedRuns" => lines.sum { |line| line.earned_runs.to_i },
        "homeRuns" => lines.sum { |line| line.home_runs.to_i },
        "baseOnBalls" => lines.sum { |line| line.walks.to_i },
        "strikeOuts" => lines.sum { |line| line.strikeouts.to_i }
      }
    end
  end

  def team_game_lines(team, category)
    line_model = category == "batting" ? GamePlayerBattingLine : GamePlayerPitchingLine

    line_model.joins(game: :schedule)
      .where(team:, games: { game_type: "R", status: "final" }, schedules: { season: })
      .to_a
  end

  def player_stat_rows(player, category)
    PlayerSeasonStat.joins(:stat_type)
      .where(player:, season:, stat_types: { category: })
      .includes(:stat_type)
      .to_a
  end

  def stat_value(rows, definition, prefer_combined:, local_values: nil)
    return local_values.fetch(definition.fetch(:key), 0) if local_values

    matching = rows.select { |row| row.stat_type.name.in?(definition.fetch(:aliases)) }
    # The stat catalog includes display/import aliases (for example, both
    # `rbi` and `RBI`). They represent the same underlying value, not separate
    # contributions. Prefer the first alias, which is the canonical local key,
    # and use the remaining aliases only for older imported data.
    canonical = matching.select { |row| row.stat_type.name == definition.fetch(:aliases).first }
    matching = canonical if canonical.any?
    matching = matching.select { |row| row.scope_type == "combined" } if prefer_combined && matching.any? { |row| row.scope_type == "combined" }
    return 0 if matching.empty?

    return matching.sum { |row| innings_to_outs(row.value) } if definition[:innings]

    matching.sum { |row| row.value.to_d }
  end

  def equal_stat_values?(local_value, official_value, definition)
    return local_value == innings_to_outs(official_value) if definition[:innings]

    local_value.to_d == official_value.to_d
  end

  def display_value(value, definition)
    return outs_to_innings(value) if definition[:innings]

    value.to_d.to_s("F")
  end

  def innings_to_outs(value)
    innings = value.to_d
    whole = innings.floor
    (whole * 3) + ((innings - whole) * 10).round
  end

  def outs_to_innings(outs)
    "#{outs / 3}.#{outs % 3}"
  end

  def local_record(team)
    games = Game.joins(:schedule)
      .where(schedules: { season: }, game_type: "R", status: "final")
      .where.not(home_score: nil, away_score: nil)
      .where("home_team_id = :team_id OR away_team_id = :team_id", team_id: team.id)

    games.each_with_object({ wins: 0, losses: 0 }) do |game, record|
      scored, allowed = game.home_team_id == team.id ? [ game.home_score, game.away_score ] : [ game.away_score, game.home_score ]
      record[:wins] += 1 if scored > allowed
      record[:losses] += 1 if scored < allowed
    end
  end

  def live_game_today?(team)
    Game.where(official_date: ApplicationCalendar.current_date, status: "live")
      .where("home_team_id = :team_id OR away_team_id = :team_id", team_id: team.id)
      .exists?
  end

  def selected_teams
    @selected_teams ||= Team.where(mlb_id: team_mlb_ids).index_by(&:mlb_id).values_at(*team_mlb_ids).compact
  end

  def team_mlb_ids
    Array(official_reconciliation_config[:team_mlb_ids]).filter_map { |id| Integer(id, exception: false) }.presence || DEFAULT_TEAM_MLB_IDS
  end

  def player_selections
    Array(official_reconciliation_config[:player_selections]).filter_map do |selection|
      data = selection.to_h.stringify_keys
      next unless Integer(data["mlb_id"], exception: false) && TEAM_STAT_DEFINITIONS.key?(data["category"])

      data
    end.presence || DEFAULT_PLAYER_SELECTIONS
  end

  def official_reconciliation_config
    NineLensConfig.fetch(:operations).fetch(:official_reconciliation, {})
  end

  def build_check(id:, name:, affected_count:, examples:, recommendation:)
    {
      id:,
      category: "Official MLB reconciliation",
      name:,
      status: affected_count.positive? ? "warning" : "healthy",
      affected_count:,
      description: "Compares selected locally stored #{season} regular-season totals with MLB's official Stats API.",
      recommendation:,
      examples: examples.first(5)
    }
  end

  def unavailable_check(id, name, error)
    build_check(
      id:,
      name:,
      affected_count: 1,
      examples: [ "MLB Stats API unavailable: #{error.message}" ],
      recommendation: "Confirm MLB Stats API connectivity, then re-run this reconciliation."
    )
  end
end
