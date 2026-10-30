class SeasonReviewQuery
  BATTING_QUALIFIER_PER_TEAM_GAME = 3.1
  HIGHLIGHT_LIMIT = 8
  LEADER_DEFINITIONS = [
    { label: "WAR", category: "batting", names: %w[WAR war] },
    { label: "OPS", category: "batting", names: %w[ops OPS], qualifier: :plate_appearances },
    { label: "Batting average", category: "batting", names: %w[avg AVG], qualifier: :plate_appearances },
    { label: "Home runs", category: "batting", name: "homeRuns" },
    { label: "Hits", category: "batting", name: "hits" },
    { label: "Triples", category: "batting", name: "triples" },
    { label: "ERA", category: "pitching", names: %w[ERA era], qualifier: :innings_pitched },
    { label: "Strikeouts", category: "pitching", name: "SO" },
    { label: "Wins", category: "pitching", name: "W" },
    { label: "Saves", category: "pitching", names: %w[SV saves] }
  ].freeze

  def initialize(season: nil)
    @requested_season = season
  end

  def result
    {
      season: season,
      available_seasons: available_seasons,
      games: games.count,
      totals: batting_totals,
      shutouts: games.count { |game| game.home_score.zero? || game.away_score.zero? },
      one_run_games: games.count { |game| (game.home_score - game.away_score).abs == 1 },
      complete_games: complete_games,
      fastest_pitches: fastest_pitches,
      top_exit_velocities: top_exit_velocities,
      longest_balls: longest_balls,
      leaders: leaders,
      champions: champions,
      postseason_teams: postseason_teams,
      world_series: world_series,
      awards_available: SeasonAward.where(season: season).exists?
    }
  end

  private

  attr_reader :requested_season

  def season
    @season ||= begin
      value = Integer(requested_season, exception: false) if requested_season.present?
      raise ArgumentError, "Season must be a valid year" if requested_season.present? && value.nil?
      value || available_seasons.max || ApplicationCalendar.current_date.year
    end
  end

  def available_seasons
    @available_seasons ||= Schedule.distinct.order(:season).pluck(:season)
  end

  def games
    @games ||= Game.joins(:schedule).where(schedules: { season: season }, game_type: "R", status: "final")
      .where.not(home_score: nil, away_score: nil)
      .select(:id, :home_team_id, :away_team_id, :home_score, :away_score).to_a
  end

  def batting_totals
    lines = GamePlayerBattingLine.joins(game: :schedule)
      .where(schedules: { season: season }, games: { game_type: "R", status: "final" })
    fields = %i[hits strikeouts walks home_runs triples]
    values = lines.pick(*fields.map { |field| Arel.sql("COALESCE(SUM(game_player_batting_lines.#{field}), 0)") })
    fields.zip(values).to_h
  end

  def complete_games
    rows = PlayerSeasonStat.joins(:stat_type)
      .where(season: season, scope_type: %w[combined team], stat_types: { category: "pitching", name: %w[CG completeGames] })
      .pluck(:player_id, :scope_type, :scope_key, "stat_types.name", :value)

    rows.group_by(&:first).sum do |_player_id, player_rows|
      combined = player_rows.select { |row| row[1] == "combined" }
      if (value = preferred_opportunity(combined, %w[CG completeGames]))
        value.to_i
      else
        player_rows.select { |row| row[1] == "team" }.group_by { |row| row[2] }
          .values.sum { |team_rows| preferred_opportunity(team_rows, %w[CG completeGames]).to_i }
      end
    end
  end

  def fastest_pitches
    PitchDatum.where(game_date: Date.new(season, 1, 1)..Date.new(season, 12, 31), game_type: "R")
      .where.not(release_speed: nil).order(release_speed: :desc).limit(HIGHLIGHT_LIMIT)
      .select(:player_name, :release_speed, :pitch_name, :game_date)
      .map { |pitch| { player: pitch.player_name, speed: pitch.release_speed, pitch: pitch.pitch_name, date: pitch.game_date } }
  end

  def top_exit_velocities
    batted_balls = PitchDatum.where(game_date: Date.new(season, 1, 1)..Date.new(season, 12, 31), game_type: "R")
      .where.not(launch_speed: nil).where.not(batter: nil).order(launch_speed: :desc).limit(HIGHLIGHT_LIMIT)
      .select(:batter, :launch_speed, :events, :game_date).to_a
    batters = Player.where(mlb_id: batted_balls.map(&:batter)).index_by(&:mlb_id)

    batted_balls.map do |ball|
      { player: batters[ball.batter]&.full_name, speed: ball.launch_speed, event: ball.events, date: ball.game_date }
    end
  end

  def longest_balls
    batted_balls = PitchDatum.where(game_date: Date.new(season, 1, 1)..Date.new(season, 12, 31), game_type: "R")
      .where.not(hit_distance_sc: nil).where.not(batter: nil).order(hit_distance_sc: :desc).limit(HIGHLIGHT_LIMIT)
      .select(:batter, :hit_distance_sc, :events, :game_date).to_a
    batters = Player.where(mlb_id: batted_balls.map(&:batter)).index_by(&:mlb_id)

    batted_balls.map do |ball|
      { player: batters[ball.batter]&.full_name, distance: ball.hit_distance_sc, event: ball.events, date: ball.game_date }
    end
  end

  def leaders
    LEADER_DEFINITIONS.map do |definition|
      category = definition.fetch(:category)
      names = definition[:names] || [ definition.fetch(:name) ]
      stat = names.lazy.filter_map { |name| StatType.cached_where(category: category, name: name).first }
        .find { |candidate| PlayerSeasonStat.where(season: season, stat_type: candidate).exists? }
      rows = stat ? PlayerSeasonStat.where(season: season, stat_type: stat).where.not(scope_type: "league")
        .where("scope_type = 'combined' OR (scope_type = 'team' AND NOT EXISTS (SELECT 1 FROM player_season_stats combined WHERE combined.player_id = player_season_stats.player_id AND combined.stat_type_id = player_season_stats.stat_type_id AND combined.season = player_season_stats.season AND combined.scope_type = 'combined'))")
        .joins(:player).includes(:player, :team) : PlayerSeasonStat.none
      rows = rows.where(player_id: qualified_player_ids(definition[:qualifier])) if definition[:qualifier]
      rows = rows.order(value: definition[:qualifier] == :innings_pitched ? :asc : :desc).limit(5)
      { category: definition.fetch(:label), qualifier: qualification_label(definition[:qualifier]), entries: rows.map { |row| { player: row.player.full_name, team: row.team&.abbreviation, value: row.value.to_f } } }
    end
  end

  def league_game_count
    @league_game_count ||= games.flat_map { |game| [ game.home_team_id, game.away_team_id ] }.tally.values.max.to_i
  end

  def qualification_label(qualifier)
    case qualifier
    when :plate_appearances then "Min. #{minimum_plate_appearances} PA"
    when :innings_pitched then "Min. #{league_game_count} IP"
    end
  end

  def minimum_plate_appearances
    @minimum_plate_appearances ||= (league_game_count * BATTING_QUALIFIER_PER_TEAM_GAME).round
  end

  def qualified_player_ids(qualifier)
    return [] if league_game_count.zero?

    @qualified_player_ids ||= {}
    @qualified_player_ids[qualifier] ||= begin
      category, aliases = qualifier == :plate_appearances ? [ "batting", %w[plateAppearances PA] ] : [ "pitching", %w[inningsPitched IP] ]
      rows = PlayerSeasonStat.joins(:stat_type)
        .where(season: season, scope_type: %w[combined team], stat_types: { category: category, name: aliases })
        .pluck(:player_id, :scope_type, :scope_key, "stat_types.name", :value)

      rows.group_by(&:first).filter_map do |player_id, player_rows|
        combined = player_rows.select { |row| row[1] == "combined" }
        values = if (value = preferred_opportunity(combined, aliases))
          [ value ]
        else
          player_rows.select { |row| row[1] == "team" }.group_by { |row| row[2] }.values.filter_map { |team_rows| preferred_opportunity(team_rows, aliases) }
        end
        opportunity = qualifier == :plate_appearances ? values.sum(&:to_f) : values.sum { |value| BaseballInnings.to_outs(value).to_i }
        threshold = qualifier == :plate_appearances ? minimum_plate_appearances : league_game_count * 3
        player_id if opportunity >= threshold
      end
    end
  end

  def preferred_opportunity(rows, aliases)
    aliases.each do |name|
      row = rows.find { |entry| entry[3] == name }
      return row[4] if row
    end
    nil
  end

  def postseason_games
    @postseason_games ||= Game.joins(:schedule).includes(:home_team, :away_team)
      .where(schedules: { season: season }, game_type: %w[F D L W], status: "final")
      .where.not(home_score: nil, away_score: nil)
      .select(:id, :game_type, :home_team_id, :away_team_id, :home_score, :away_score).to_a
  end

  def postseason_teams
    postseason_games.flat_map { |game| [ game.home_team, game.away_team ] }.uniq(&:id).map do |team|
      wins = postseason_games.count do |game|
        (game.home_team_id == team.id && game.home_score > game.away_score) || (game.away_team_id == team.id && game.away_score > game.home_score)
      end
      { id: team.id, name: team.team_name, abbreviation: team.abbreviation, wins: wins }
    end.sort_by { |team| [ -team[:wins], team[:name] ] }
  end

  def champions
    {
      status: season < ApplicationCalendar.current_date.year ? "historical" : "current",
      world: series_winner(postseason_games.select { |game| game.game_type == "W" }),
      leagues: %w[american national].map do |league|
        teams = division_teams.select { |division| division.fetch(:league) == league }.flat_map { |division| division.fetch(:teams) }
        { name: league == "american" ? "American League" : "National League",
          team: series_winner(postseason_games.select { |game| game.game_type == "L" && teams.include?(game.home_team_id) && teams.include?(game.away_team_id) }) }
      end,
      divisions: division_teams.map do |division|
        { name: division.fetch(:name), team: division_winner(division) }
      end
    }
  end

  def division_teams
    @division_teams ||= StandingsSnapshotQuery::DIVISIONS.map do |division|
      division.slice(:name, :league).merge(teams: Team.where(mlb_id: division.fetch(:team_mlb_ids)).pluck(:id))
    end
  end

  def division_winner(division)
    return unless games.any?
    return unless regular_season_complete?

    rows = division.fetch(:teams).filter_map do |team_id|
      played = games.select { |game| game.home_team_id == team_id || game.away_team_id == team_id }
      next if played.empty?

      wins = played.count do |game|
        team_id == game.home_team_id ? game.home_score > game.away_score : game.away_score > game.home_score
      end
      [team_id, wins, played.length]
    end
    return if rows.empty?

    ranked = rows.sort_by { |team_id, wins, played| [-(wins.to_f / played), -wins, team_id] }
    return if ranked.second && ranked.first[1].to_f / ranked.first[2] == ranked.second[1].to_f / ranked.second[2]

    winner = ranked.first
    team_payload(Team.find(winner.first))
  end

  def regular_season_complete?
    return @regular_season_complete if defined?(@regular_season_complete)

    @regular_season_complete = season < ApplicationCalendar.current_date.year ||
      !Game.joins(:schedule).where(schedules: { season: season }, game_type: "R")
        .where.not(status: %w[final canceled cancelled]).exists?
  end

  def series_winner(series)
    wins = series.each_with_object(Hash.new(0)) do |game, counts|
      team_id = game.home_score > game.away_score ? game.home_team_id : game.away_team_id
      counts[team_id] += 1
    end
    team_id, count = wins.max_by { |_id, total| total }
    return unless count.to_i >= 4

    team_payload(Team.find(team_id))
  end

  def team_payload(team)
    { id: team.id, name: team.name, abbreviation: team.abbreviation, logo_url: team.logo_url }
  end

  def world_series
    series = postseason_games.select { |game| game.game_type == "W" }
    wins = Hash.new(0)
    series.each do |game|
      winner = game.home_score > game.away_score ? game.home_team : game.away_team
      wins[winner.id] += 1
    end
    champion_id = wins.max_by { |_id, count| count }&.first if wins.values.max.to_i >= 4
    { teams: series.flat_map { |game| [ game.home_team, game.away_team ] }.uniq(&:id).map(&:team_name), champion: series.flat_map { |game| [ game.home_team, game.away_team ] }.uniq(&:id).find { |team| team.id == champion_id }&.team_name }
  end
end
