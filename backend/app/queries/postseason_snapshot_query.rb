class PostseasonSnapshotQuery
  POSTSEASON_GAME_TYPES = %w[F D L W].freeze
  BATTING_AT_BATS_PER_TEAM_GAME = 3.1
  PITCHING_INNINGS_PER_TEAM_GAME = 1.0
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
    return payload.merge(playoff_teams: [], game_results: [], upcoming_games: [], rounds: [], leaders: empty_leaders) unless payload[:active]

    payload.merge(
      playoff_teams: playoff_teams(games),
      game_results: games.select { |game| game.status == "final" }.map { |game| GameSerializer.call(game) },
      upcoming_games: games.reject { |game| %w[final canceled cancelled].include?(game.status) }.map { |game| GameSerializer.call(game) },
      rounds: rounds(games),
      leaders: postseason_leaders(games)
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
      .without_unplayed_if_necessary
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
    label = description.sub(/\s+Game\s+\d+.*\z/i, "").strip
    label.presence || game.raw_data.to_h["seriesDescription"].presence || "Series"
  end

  def series_payload(games)
    teams = games.flat_map { |game| [game.home_team, game.away_team] }.uniq(&:id)
    {
      key: series_key(games.first).parameterize,
      name: series_key(games.first),
      league: series_league(games),
      teams: teams.map { |team| team_payload(team).merge(league: team_league(team, games)) },
      games: games.sort_by { |game| [game.raw_data.to_h["seriesGameNumber"].to_i, game.scheduled_at, game.mlb_id] }.map { |game| GameSerializer.call(game, include_schedule: false) }
    }
  end

  def series_league(games)
    leagues = games.filter_map { |game| league_from_description(series_key(game)) }.uniq
    leagues = games.flat_map { |game| %w[home away].filter_map { |side| league_from_raw_team(game, side) } }.uniq if leagues.empty?
    leagues.one? ? leagues.first : nil
  end

  def team_league(team, games)
    games.each do |game|
      %w[home away].each do |side|
        raw_team = game.raw_data.to_h.dig("teams", side, "team").to_h
        next unless raw_team["id"].to_i == team.mlb_id

        league = league_from_id(raw_team.dig("league", "id"))
        return league if league
      end
    end

    league_from_description(games.filter_map { |game| series_key(game) }.first)
  end

  def league_from_raw_team(game, side)
    league_from_id(game.raw_data.to_h.dig("teams", side, "team", "league", "id"))
  end

  def league_from_id(id)
    { 103 => "AL", 104 => "NL" }[id.to_i]
  end

  def league_from_description(value)
    text = value.to_s.upcase
    return "AL" if text.match?(/\AAL(?:CS|DS|\s)/) || text.include?("AMERICAN LEAGUE")
    return "NL" if text.match?(/\ANL(?:CS|DS|\s)/) || text.include?("NATIONAL LEAGUE")
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

  def postseason_leaders(games)
    completed_games = games.select { |game| game.status == "final" }
    return empty_leaders if completed_games.empty?

    team_game_counts = completed_games.each_with_object(Hash.new(0)) do |game, counts|
      counts[game.home_team_id] += 1
      counts[game.away_team_id] += 1
    end

    {
      batting: batting_leaders(completed_games.map(&:id), team_game_counts),
      pitching: pitching_leaders(completed_games.map(&:id), team_game_counts)
    }
  end

  def empty_leaders
    { batting: [], pitching: [] }
  end

  def batting_leaders(game_ids, team_game_counts)
    GamePlayerBattingLine.includes(:game, :player, :team).where(game_id: game_ids).group_by(&:player_id).values.filter_map do |lines|
      at_bats = lines.sum { |line| line.at_bats.to_i }
      hits = lines.sum { |line| line.hits.to_i }
      doubles = lines.sum { |line| line.doubles.to_i }
      triples = lines.sum { |line| line.triples.to_i }
      home_runs = lines.sum { |line| line.home_runs.to_i }
      walks = lines.sum { |line| line.walks.to_i }
      plate_appearances = lines.sum { |line| line.plate_appearances.to_i }
      plate_appearances = at_bats + walks if plate_appearances.zero?
      next if plate_appearances.zero?

      last_line = lines.max_by { |line| [line.game.official_date, line.game.id] }
      minimum_at_bats = (team_game_counts[last_line.team_id] * BATTING_AT_BATS_PER_TEAM_GAME).ceil
      next if at_bats < minimum_at_bats

      batting_average = rate(hits, at_bats)
      on_base_percentage = rate(hits + walks, at_bats + walks)
      slugging_percentage = rate(hits + doubles + (2 * triples) + (3 * home_runs), at_bats)

      {
        player: player_payload(last_line.player),
        team: team_payload(last_line.team),
        games: lines.map(&:game_id).uniq.length,
        plate_appearances: plate_appearances,
        at_bats: at_bats,
        runs: lines.sum { |line| line.runs.to_i },
        hits: hits,
        home_runs: home_runs,
        runs_batted_in: lines.sum { |line| line.runs_batted_in.to_i },
        batting_average: batting_average,
        ops: rounded_rate(on_base_percentage && slugging_percentage ? on_base_percentage + slugging_percentage : nil)
      }
    end.sort_by { |row| [-(row[:ops] || -1), -row[:home_runs], -row[:hits], row.dig(:player, :full_name)] }.first(10)
  end

  def pitching_leaders(game_ids, team_game_counts)
    GamePlayerPitchingLine.includes(:game, :player, :team).where(game_id: game_ids).group_by(&:player_id).values.filter_map do |lines|
      outs = lines.sum { |line| line.outs_recorded.to_i }
      next if outs.zero?

      last_line = lines.max_by { |line| [line.game.official_date, line.game.id] }
      minimum_outs = (team_game_counts[last_line.team_id] * PITCHING_INNINGS_PER_TEAM_GAME * 3).ceil
      next if outs < minimum_outs

      hits = lines.sum { |line| line.hits.to_i }
      walks = lines.sum { |line| line.walks.to_i }
      earned_runs = lines.sum { |line| line.earned_runs.to_i }

      {
        player: player_payload(last_line.player),
        team: team_payload(last_line.team),
        games: lines.map(&:game_id).uniq.length,
        innings_pitched: innings_pitched(outs),
        wins: lines.count { |line| pitching_decision?(line, "W") },
        losses: lines.count { |line| pitching_decision?(line, "L") },
        saves: lines.sum { |line| line.saves.to_i },
        hits: hits,
        earned_runs: earned_runs,
        walks: walks,
        strikeouts: lines.sum { |line| line.strikeouts.to_i },
        era: rounded_rate((earned_runs * 27.0) / outs),
        whip: rounded_rate(((hits + walks) * 3.0) / outs)
      }
    end.sort_by { |row| [row[:era], -row[:strikeouts], -row[:innings_pitched].to_f, row.dig(:player, :full_name)] }.first(10)
  end

  def player_payload(player)
    { id: player.id, mlb_id: player.mlb_id, full_name: player.full_name }
  end

  def rate(numerator, denominator)
    return if denominator.zero?

    rounded_rate(numerator.to_f / denominator)
  end

  def rounded_rate(value)
    value&.round(3)
  end

  def innings_pitched(outs)
    "#{outs / 3}.#{outs % 3}"
  end

  def pitching_decision?(line, decision)
    line.decision.to_s.match?(/\A\(?#{decision}(?:,|\)?\z)/)
  end
end
