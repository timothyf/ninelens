class StandingsSnapshotQuery
  DIVISIONS = [
    { key: "al_east", name: "AL East", league: "american", team_mlb_ids: [ 110, 111, 147, 139, 141 ] },
    { key: "al_central", name: "AL Central", league: "american", team_mlb_ids: [ 145, 114, 116, 118, 142 ] },
    { key: "al_west", name: "AL West", league: "american", team_mlb_ids: [ 133, 117, 108, 136, 140 ] },
    { key: "nl_east", name: "NL East", league: "national", team_mlb_ids: [ 144, 146, 121, 143, 120 ] },
    { key: "nl_central", name: "NL Central", league: "national", team_mlb_ids: [ 112, 113, 158, 134, 138 ] },
    { key: "nl_west", name: "NL West", league: "national", team_mlb_ids: [ 109, 115, 119, 135, 137 ] }
  ].freeze

  def initialize(season: nil)
    @requested_season = season
  end

  def result
    divisions = DIVISIONS.map { |division| division_payload(division).merge(league: division.fetch(:league)) }
    projection = playoff_projection(divisions)

    {
      season: season,
      available_seasons: available_seasons,
      as_of: completed_games.maximum(:official_date),
      season_status: season_complete? ? "final" : "in_progress",
      playoff_odds: projection.except(:teams),
      leagues: %w[american national].map do |league|
        league_divisions = divisions.select { |division| division.fetch(:league) == league }.map do |division|
          division.except(:league).merge(teams: add_playoff_odds(division.fetch(:teams), projection.fetch(:teams)))
        end
        {
          key: league,
          name: league == "american" ? "American League" : "National League",
          divisions: league_divisions,
          wild_card: wild_card_payload(league_divisions)
        }
      end
    }
  end

  def division_rank_for(team)
    division = DIVISIONS.find { |entry| entry.fetch(:team_mlb_ids).include?(team.mlb_id) }
    return nil unless division

    payload = division_payload(division)
    teams = payload.fetch(:teams)
    row = teams.find { |entry| entry.dig(:team, :id) == team.id }
    return nil unless row

    gap = if row.fetch(:rank) == 1
      { games_ahead: teams.second&.fetch(:games_back) || 0.0 }
    else
      { games_behind: row.fetch(:games_back) }
    end

    {
      rank: row.fetch(:rank),
      total_teams: teams.length,
      division: { key: payload.fetch(:key), name: payload.fetch(:name) }
    }.merge(gap)
  end

  private

  attr_reader :requested_season

  def season
    @season ||= begin
      normalized = Integer(requested_season, exception: false) if requested_season.present?
      raise ArgumentError, "Season must be a valid year" if requested_season.present? && normalized.nil?

      normalized || available_seasons.max || ApplicationCalendar.current_date.year
    end
  end

  def available_seasons
    @available_seasons ||= Schedule.distinct.order(:season).pluck(:season)
  end

  def completed_games
    @completed_games ||= Game
      .joins(:schedule)
      .where(schedules: { season: season }, game_type: "R", status: "final")
      .where.not(home_score: nil, away_score: nil)
  end

  def games
    @games ||= completed_games.select(:home_team_id, :away_team_id, :home_score, :away_score).to_a
  end

  def remaining_games
    @remaining_games ||= Game
      .joins(:schedule)
      .where(schedules: { season: season }, game_type: "R")
      .where.not(status: [ "final", "canceled", "cancelled"])
      .where.not("LOWER(COALESCE(games.detailed_status, '')) LIKE ?", "%cancel%")
      .select(:home_team_id, :away_team_id)
      .to_a
  end

  def season_complete?
    return true if season < ApplicationCalendar.current_date.year
    return false unless season == ApplicationCalendar.current_date.year

    remaining_games.empty?
  end

  def playoff_projection(divisions)
    PlayoffOddsProjection.new(
      divisions: divisions,
      remaining_games: remaining_games,
      seed: season
    ).result
  end

  def add_playoff_odds(rows, odds)
    rows.map { |row| row.merge(playoff_odds: odds.fetch(row.dig(:team, :id), { division: 0.0, wild_card: 0.0, playoffs: 0.0 })) }
  end

  def teams_by_mlb_id
    @teams_by_mlb_id ||= Team.where(mlb_id: DIVISIONS.flat_map { |division| division.fetch(:team_mlb_ids) }).index_by(&:mlb_id)
  end

  def division_payload(division)
    rows = division.fetch(:team_mlb_ids).filter_map do |mlb_id|
      team = teams_by_mlb_id[mlb_id]
      standings_row(team) if team
    end
    sorted = rows.sort_by { |row| [ -row.fetch(:winning_percentage), -row.fetch(:wins), row.dig(:team, :name) ] }
    leader = sorted.first

    {
      key: division.fetch(:key),
      name: division.fetch(:name),
      teams: sorted.map.with_index do |row, index|
        row.merge(rank: index + 1, games_back: games_back(row, leader))
      end
    }
  end

  def standings_row(team)
    totals = team_games(team).each_with_object({ wins: 0, losses: 0, ties: 0, runs_scored: 0, runs_allowed: 0 }) do |game, result|
      scored, allowed = game.home_team_id == team.id ? [ game.home_score, game.away_score ] : [ game.away_score, game.home_score ]
      result[:runs_scored] += scored
      result[:runs_allowed] += allowed
      result[:wins] += 1 if scored > allowed
      result[:losses] += 1 if scored < allowed
      result[:ties] += 1 if scored == allowed
    end
    played = totals[:wins] + totals[:losses] + totals[:ties]

    {
      team: {
        id: team.id,
        mlb_id: team.mlb_id,
        name: team.name,
        abbreviation: team.abbreviation,
        logo_url: team.logo_url
      },
      games_played: played,
      wins: totals[:wins],
      losses: totals[:losses],
      ties: totals[:ties],
      winning_percentage: played.positive? ? ((totals[:wins] + totals[:ties] * 0.5) / played.to_f).round(3) : 0.0,
      runs_scored: totals[:runs_scored],
      runs_allowed: totals[:runs_allowed],
      run_differential: totals[:runs_scored] - totals[:runs_allowed]
    }
  end

  def wild_card_payload(divisions)
    candidates = divisions.flat_map do |division|
      division.fetch(:teams).drop(1).map do |row|
        row.merge(division: { key: division.fetch(:key), name: division.fetch(:name) })
      end
    end
    sorted = candidates.sort_by { |row| [ -row.fetch(:winning_percentage), -row.fetch(:wins), row.dig(:team, :name) ] }
    cutoff = sorted[2]

    {
      cutoff_positions: 3,
      teams: sorted.map.with_index do |row, index|
        row.merge(
          rank: index + 1,
          wild_card_position: index < 3 ? index + 1 : nil,
          wild_card_games_back: index < 3 || cutoff.nil? ? 0.0 : games_back(row, cutoff)
        )
      end
    }
  end

  def team_games(team)
    games.select { |game| game.home_team_id == team.id || game.away_team_id == team.id }
  end

  def games_back(row, leader)
    return 0.0 unless leader

    ((leader.fetch(:wins) - row.fetch(:wins) + row.fetch(:losses) - leader.fetch(:losses)) / 2.0).round(1)
  end
end
