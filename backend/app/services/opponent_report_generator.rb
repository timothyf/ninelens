class OpponentReportGenerator
  UPCOMING_GAME_LIMIT = 5

  def self.call(team:, season:, owner:, on: Date.current)
    new(team: team, season: season, on: on, owner: owner).call
  end

  def initialize(team:, season:, on:, owner:)
    @team = team
    @season = Integer(season)
    @on = on
    @owner = owner
  end

  def call
    preparation = preparation_query.result
    opponent_id = preparation.dig(:opponent, :id)
    raise ArgumentError, "No upcoming opponent is available for this season." unless opponent_id

    games = series_games(opponent_id)
    return report if games.empty?
    opponent = Team.find(opponent_id)
    generated_at = Time.current

    OpponentReport.create!(
      team: team,
      owner: owner,
      opponent_team: opponent,
      season: season,
      series_starts_on: games.first.official_date,
      series_ends_on: games.last.official_date,
      title: "#{team.abbreviation} vs #{opponent.abbreviation} · #{series_label(games)}",
      generated_at: generated_at,
      snapshot: snapshot_for(preparation, games, opponent, generated_at)
    )
  end

  def refresh!(report)
    preparation = preparation_query.result
    opponent_id = preparation.dig(:opponent, :id)
    return report unless opponent_id

    games = series_games(opponent_id)
    opponent = Team.find(opponent_id)
    generated_at = Time.current
    report.update!(
      opponent_team: opponent,
      series_starts_on: games.first.official_date,
      series_ends_on: games.last.official_date,
      generated_at: generated_at,
      snapshot: snapshot_for(preparation, games, opponent, generated_at)
    )
    report
  end

  private

  def preparation_query
    OpponentPreparationQuery.new(
      team: team,
      upcoming_games: upcoming_games,
      season: season,
      on: on
    )
  end

  def snapshot_for(preparation, games, opponent, generated_at)
    {
      generated_at: generated_at,
      team: serialize_team(team),
      opponent: serialize_team(opponent),
      series: games.map { |game| GameSerializer.call(game) },
      roster: preparation.fetch(:roster),
      recent_performance: preparation.fetch(:recent_performance),
      expected_lineups: preparation.fetch(:expected_lineups),
      probable_starters: preparation.fetch(:probable_starters),
      bullpen: preparation.fetch(:bullpen),
      source_fingerprint: source_fingerprint(games, preparation)
    }
  end

  def source_fingerprint(games, preparation)
    [
      games.map { |game| [ game.id, game.updated_at.to_i, game.home_probable_pitcher_id, game.away_probable_pitcher_id ] },
      preparation.fetch(:roster),
      preparation.fetch(:expected_lineups).map { |lineup| lineup[:entries].map { |entry| entry.dig(:player, :id) } }
    ].flatten.hash.to_s
  end

  attr_reader :team, :season, :on, :owner

  def upcoming_games
    @upcoming_games ||= Game.for_team(team)
      .joins(:schedule)
      .where(schedules: { season: season })
      .where("official_date >= ?", on)
      .where(home_score: nil, away_score: nil)
      .includes(:schedule, :home_team, :away_team, :home_probable_pitcher, :away_probable_pitcher)
      .order(:official_date, :scheduled_at, :mlb_id)
      .limit(UPCOMING_GAME_LIMIT)
      .to_a
  end

  def series_games(opponent_id)
    upcoming_games.take_while do |game|
      [ game.home_team_id, game.away_team_id ].include?(opponent_id)
    end
  end

  def series_label(games)
    first = games.first.official_date.strftime("%b %-d")
    last = games.last.official_date.strftime("%b %-d, %Y")
    games.first.official_date == games.last.official_date ? last : "#{first}–#{last}"
  end

  def serialize_team(value)
    { id: value.id, mlb_id: value.mlb_id, name: value.name, abbreviation: value.abbreviation }
  end
end
