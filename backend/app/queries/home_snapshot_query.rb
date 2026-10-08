class HomeSnapshotQuery
  LEADER_LIMIT = 5
  RECENT_TEAM_GAME_LIMIT = 10
  RECENT_TEAM_30_GAME_LIMIT = 30
  LEADER_DEFINITIONS = [
    { key: "battingWAR", label: "Batting WAR", category: "batting", aliases: %w[WAR war], descending: true },
    { key: "ops", label: "OPS", category: "batting", aliases: %w[ops OPS], descending: true, qualifier: :at_bats },
    { key: "avg", label: "Batting average", category: "batting", aliases: %w[avg AVG], descending: true, qualifier: :at_bats },
    { key: "homeRuns", label: "Home runs", category: "batting", aliases: %w[homeRuns HR], descending: true },
    { key: "rbi", label: "RBI", category: "batting", aliases: %w[rbi RBI], descending: true },
    { key: "pitchingWAR", label: "Pitching WAR", category: "pitching", aliases: %w[WAR war], descending: true },
    { key: "wins", label: "Wins", category: "pitching", aliases: %w[wins W], descending: true },
    { key: "ERA", label: "ERA", category: "pitching", aliases: %w[ERA era], descending: false, qualifier: :innings },
    { key: "strikeOuts", label: "Strikeouts", category: "pitching", aliases: %w[strikeOuts SO], descending: true }
  ].freeze

  def initialize(on: nil, league: nil)
    @on = parse_date(on) || ApplicationCalendar.current_date
    @league = normalize_league(league)
  end

  def result
    {
      as_of: on,
      season: season,
      games: games,
      leaders: leaders,
      team_pulse: team_pulse,
      freshness: freshness
    }
  end

  private

  attr_reader :on, :league

  def normalize_league(value)
    value = value.to_s.downcase
    value.in?(%w[american national]) ? value : nil
  end

  def parse_date(value)
    Date.iso8601(value.to_s) if value.present?
  rescue ArgumentError
    nil
  end

  def season
    @season ||= Schedule
      .where("start_date <= ? AND end_date >= ?", on, on)
      .maximum(:season) || PlayerSeasonStat.maximum(:season) || on.year
  end

  def games
    Game
      .where(official_date: on)
      .without_unplayed_if_necessary
      .includes(:schedule, :home_team, :away_team, :home_probable_pitcher, :away_probable_pitcher)
      .order(:scheduled_at, :mlb_id)
      .map { |game| GameSerializer.call(game) }
  end

  def leaders
    LEADER_DEFINITIONS.map do |definition|
      rows = leaderboard_rows(definition)
      qualified_rows = apply_qualification(rows, definition[:qualifier])

      {
        key: definition.fetch(:key),
        label: definition.fetch(:label),
        category: definition.fetch(:category),
        qualifier: qualifier_label(definition[:qualifier]),
        entries: qualified_rows.first(LEADER_LIMIT).map.with_index do |row, index|
          {
            rank: index + 1,
            value: row.dig(:stats, definition.fetch(:key)),
            player: row.fetch(:player),
            team: row.fetch(:team)
          }
        end
      }
    end
  end

  def leaderboard_rows(definition)
    candidates = leaderboard_groups.filter_map do |rows|
      first = rows.first
      next unless first.stat_type.category == definition.fetch(:category)

      value = stat_value(rows, definition.fetch(:aliases))
      next if value.nil?
      next unless league_eligible?(first)

      {
        player: serialize_player(first.player),
        team: serialize_leader_team(first),
        scope: { type: first.scope_type, key: first.scope_key },
        stats: {
          definition.fetch(:key) => value,
          "atBats" => stat_value(rows, %w[atBats AB]),
          "inningsPitched" => stat_value(rows, %w[inningsPitched IP])
        }
      }
    end

    deduplicated = candidates.group_by { |row| row.dig(:player, :id) }.values.map do |player_rows|
      player_rows.find { |row| row.dig(:scope, :type) == "combined" } || best_row(player_rows, definition)
    end

    sort_rows(deduplicated, definition)
  end

  def league_eligible?(stat)
    return true if league.nil?

    MlbRosterBatchSync::TEAM_IDS_BY_LEAGUE.fetch(league).include?(stat.team&.mlb_id || stat.player.team&.mlb_id)
  end

  def leaderboard_groups
    @leaderboard_groups ||= PlayerSeasonStat
      .joins(:stat_type)
      .where(season: season, stat_types: { name: leaderboard_stat_names })
      .includes(:stat_type, :player, :team)
      .to_a
      .group_by { |row| [ row.player_id, row.team_id, row.scope_type, row.scope_key, row.stat_type.category ] }
      .values
  end

  def leaderboard_stat_names
    @leaderboard_stat_names ||= (
      LEADER_DEFINITIONS.flat_map { |definition| definition.fetch(:aliases) } +
      %w[atBats AB inningsPitched IP]
    ).uniq
  end

  def stat_value(rows, aliases)
    aliases.each do |name|
      row = rows.find { |candidate| candidate.stat_type.name == name }
      return row.value.to_s("F") if row
    end
    nil
  end

  def best_row(rows, definition)
    definition.fetch(:descending) ?
      rows.max_by { |row| row.dig(:stats, definition.fetch(:key)).to_f } :
      rows.min_by { |row| row.dig(:stats, definition.fetch(:key)).to_f }
  end

  def sort_rows(rows, definition)
    rows.sort_by do |row|
      value = row.dig(:stats, definition.fetch(:key)).to_f
      [ definition.fetch(:descending) ? -value : value, row.dig(:player, :full_name) ]
    end
  end

  def serialize_player(player)
    {
      id: player.id,
      mlb_id: player.mlb_id,
      first_name: player.first_name,
      last_name: player.last_name,
      full_name: player.full_name
    }
  end

  def serialize_leader_team(stat)
    team = stat.team || stat.player.team
    {
      id: team&.id,
      mlb_id: team&.mlb_id,
      name: team&.name || stat.scope_key,
      abbreviation: team&.abbreviation || stat.scope_key
    }
  end

  def apply_qualification(rows, qualifier)
    case qualifier
    when :at_bats
      rows.select { |row| row.dig(:stats, "atBats").to_f >= minimum_at_bats }
    when :innings
      rows.select { |row| innings_outs(row.dig(:stats, "inningsPitched")) >= minimum_innings * 3 }
    else
      rows
    end
  end

  def minimum_at_bats
    @minimum_at_bats ||= [(league_game_count * 2.7).floor, 1].max
  end

  def minimum_innings
    @minimum_innings ||= [league_game_count, 1].max
  end

  def league_game_count
    @league_game_count ||= begin
      games = Game
        .joins(:schedule)
        .where(schedules: { season: season }, game_type: "R")
        .where("official_date <= ?", on)
        .where.not(home_score: nil, away_score: nil)
        .pluck(:home_team_id, :away_team_id)

      games.flatten.compact.tally.values.max.to_i
    end
  end

  def innings_outs(value)
    decimal = BigDecimal(value.to_s)
    whole = decimal.floor
    partial = ((decimal - whole) * 10).round
    (whole * 3) + partial
  rescue ArgumentError
    0
  end

  def qualifier_label(qualifier)
    case qualifier
    when :at_bats then "Minimum #{minimum_at_bats} AB"
    when :innings then "Minimum #{minimum_innings} IP"
    end
  end

  def team_pulse
    summaries = team_summaries

    {
      best_records: summaries.sort_by { |entry| [-entry[:winning_percentage], -entry[:wins], entry.dig(:team, :name)] }.first(5),
      run_differential: summaries.sort_by { |entry| [-entry[:run_differential], entry.dig(:team, :name)] }.first(5),
      recent_form: summaries
        .select { |entry| entry[:recent_games].positive? }
        .sort_by { |entry| [-entry[:recent_winning_percentage], -entry[:recent_run_differential], entry.dig(:team, :name)] }
        .first(5),
      last_30_form: summaries
        .select { |entry| entry[:recent_30_games].positive? }
        .sort_by { |entry| [-entry[:recent_30_winning_percentage], -entry[:recent_30_run_differential], entry.dig(:team, :name)] }
        .first(5)
    }
  end

  def team_summaries
    @team_summaries ||= team_metric_rows.group_by(&:team).filter_map do |team, rows|
      totals = sum_metrics(rows)
      next if totals[:games].zero?

      recent = recent_game_summary(team)
      recent_30 = recent_game_summary(team, RECENT_TEAM_30_GAME_LIMIT)
      {
        team: serialize_team(team),
        games: totals[:games],
        wins: totals[:wins],
        losses: totals[:losses],
        ties: totals[:ties],
        winning_percentage: ratio(totals[:wins], totals[:wins] + totals[:losses]),
        run_differential: totals[:runs_scored] - totals[:runs_allowed],
        recent_games: recent[:games],
        recent_wins: recent[:wins],
        recent_losses: recent[:losses],
        recent_ties: recent[:ties],
        recent_winning_percentage: ratio(recent[:wins], recent[:wins] + recent[:losses]),
        recent_run_differential: recent[:runs_scored] - recent[:runs_allowed],
        recent_30_games: recent_30[:games],
        recent_30_wins: recent_30[:wins],
        recent_30_losses: recent_30[:losses],
        recent_30_ties: recent_30[:ties],
        recent_30_winning_percentage: ratio(recent_30[:wins], recent_30[:wins] + recent_30[:losses]),
        recent_30_run_differential: recent_30[:runs_scored] - recent_30[:runs_allowed]
      }
    end
  end

  def team_metric_rows
    return TeamDailyMetric.none if analytics_version.blank?

    TeamDailyMetric
      .where(metric_date: Date.new(season, 1, 1)..regular_season_end_date, calculation_version: analytics_version)
      .includes(:team)
      .order(:metric_date)
      .to_a
  end

  def regular_season_end_date
    @regular_season_end_date ||= Game
      .joins(:schedule)
      .where(schedules: { season: season }, game_type: "R")
      .where("official_date <= ?", on)
      .maximum(:official_date) || on
  end

  def analytics_version
    @analytics_version ||= TeamDailyMetric.order(calculated_at: :desc).pick(:calculation_version)
  end

  def sum_metrics(rows)
    rows.each_with_object({ games: 0, wins: 0, losses: 0, ties: 0, runs_scored: 0, runs_allowed: 0 }) do |row, totals|
      totals.each_key { |key| totals[key] += row.metrics.to_h[key.to_s].to_i }
    end
  end

  def recent_game_summary(team, limit = RECENT_TEAM_GAME_LIMIT)
    games = completed_games_by_team.fetch(team.id, []).last(limit)
    games.each_with_object({ games: games.length, wins: 0, losses: 0, ties: 0, runs_scored: 0, runs_allowed: 0 }) do |game, totals|
      scored, allowed = game.home_team_id == team.id ? [ game.home_score, game.away_score ] : [ game.away_score, game.home_score ]
      totals[:runs_scored] += scored
      totals[:runs_allowed] += allowed
      totals[:wins] += 1 if scored > allowed
      totals[:losses] += 1 if scored < allowed
      totals[:ties] += 1 if scored == allowed
    end
  end

  def completed_games_by_team
    @completed_games_by_team ||= begin
      grouped = Hash.new { |hash, team_id| hash[team_id] = [] }
      Game
        .joins(:schedule)
        .where(schedules: { season: season }, game_type: "R", status: "final")
        .where("official_date <= ?", on)
        .where.not(home_score: nil, away_score: nil)
        .order(:official_date, :scheduled_at, :mlb_id)
        .select(:id, :mlb_id, :official_date, :scheduled_at, :home_team_id, :away_team_id, :home_score, :away_score)
        .each do |game|
          grouped[game.home_team_id] << game
          grouped[game.away_team_id] << game
        end
      grouped
    end
  end

  def ratio(numerator, denominator)
    return 0.0 if denominator.zero?

    (numerator.to_f / denominator).round(3)
  end

  def serialize_team(team)
    {
      id: team.id,
      mlb_id: team.mlb_id,
      name: team.name,
      abbreviation: team.abbreviation,
      logo_url: team.logo_url
    }
  end

  def freshness
    {
      schedule: Game.maximum(:last_synced_at),
      game_details: Game.maximum(:details_last_synced_at),
      player_stats: PlayerSeasonStat.maximum(:updated_at),
      analytics: TeamDailyMetric.maximum(:calculated_at)
    }
  end
end
