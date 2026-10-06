class PostseasonSnapshotQuery
  POSTSEASON_GAME_TYPES = %w[F D L W].freeze
  ROUND_NAMES = {
    "F" => "Wild Card",
    "D" => "Division Series",
    "L" => "League Championship Series",
    "W" => "World Series"
  }.freeze

  def initialize(season: nil, today: ApplicationCalendar.current_date)
    @requested_season = season
    @today = today
  end

  def result
    games = postseason_games.to_a
    payload = { season: season, active: active?(games), available_seasons: available_seasons }
    return payload.merge(playoff_teams: [], game_results: [], upcoming_games: [], rounds: []) unless payload[:active]

    payload.merge(
      playoff_teams: playoff_teams(games),
      game_results: games.select { |game| game.status == "final" },
      upcoming_games: games.reject { |game| %w[final canceled cancelled].include?(game.status) },
      rounds: rounds(games)
    )
  end

  private

  attr_reader :requested_season, :today

  def season
    @season ||= begin
      value = Integer(requested_season, exception: false) if requested_season.present?
      raise ArgumentError, "Season must be a valid year" if requested_season.present? && value.nil?

      value || today.year
    end
  end

  def available_seasons
    @available_seasons ||= Schedule.joins(:games).where(games: { game_type: POSTSEASON_GAME_TYPES }).distinct.order(:season).pluck(:season)
  end

  def postseason_games
    @postseason_games ||= Game
      .joins(:schedule)
      .includes(:home_team, :away_team)
      .where(schedules: { season: season }, game_type: POSTSEASON_GAME_TYPES)
      .where.not(
        "games.status IN (?) AND COALESCE(games.raw_data ->> 'ifNecessary', 'N') = ?",
        %w[scheduled preview],
        "Y"
      )
      .chronological
  end

  def active?(games)
    return false unless season == today.year

    dates = games.filter_map { |game| game.official_date unless cancelled?(game) }
    dates.any? && dates.min <= today && dates.max >= today
  end

  def cancelled?(game)
    %w[canceled cancelled].include?(game.status) || game.detailed_status.to_s.downcase.include?("cancel")
  end

  def playoff_teams(games)
    rows = games.flat_map { |game| [game.home_team, game.away_team] }.uniq(&:id)
    rows.map do |team|
      team_games = games.select { |game| [game.home_team_id, game.away_team_id].include?(team.id) && game.status == "final" }
      wins = team_games.count do |game|
        team_score(game, team) > opponent_score(game, team)
      end
      { team: team_payload(team), wins: wins, losses: team_games.length - wins }
    end.sort_by { |row| [-row[:wins], row.dig(:team, :name)] }
  end

  def rounds(games)
    games.group_by(&:game_type).sort_by { |type, _| POSTSEASON_GAME_TYPES.index(type) }.map do |type, round_games|
      {
        key: ROUND_NAMES.fetch(type).parameterize,
        name: ROUND_NAMES.fetch(type),
        series: round_games.group_by { |game| series_key(game) }.values.map { |series_games| series_payload(series_games) }
      }
    end
  end

  def series_key(game)
    description = game.raw_data.to_h["description"].to_s
    label = description.sub(/\s+Game\s+\d+\s*\z/i, "").strip
    label.presence || game.raw_data.to_h["seriesDescription"].presence || "Series"
  end

  def series_payload(games)
    teams = games.flat_map { |game| [game.home_team, game.away_team] }.uniq(&:id)
    {
      key: series_key(games.first).parameterize,
      name: series_key(games.first),
      teams: teams.map { |team| team_payload(team) },
      games: games.sort_by { |game| [game.raw_data.to_h["seriesGameNumber"].to_i, game.scheduled_at, game.mlb_id] }.map { |game| GameSerializer.call(game, include_schedule: false) }
    }
  end

  def team_score(game, team)
    team.id == game.home_team_id ? game.home_score.to_i : game.away_score.to_i
  end

  def opponent_score(game, team)
    team.id == game.home_team_id ? game.away_score.to_i : game.home_score.to_i
  end

  def team_payload(team)
    { id: team.id, mlb_id: team.mlb_id, name: team.name, abbreviation: team.abbreviation, logo_url: team.logo_url }
  end
end
