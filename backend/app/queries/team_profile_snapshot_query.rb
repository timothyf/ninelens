class TeamProfileSnapshotQuery
  GAME_LIMIT = 5
  RECENT_GAME_WINDOWS = [ 7, 15, 30 ].freeze
  RECENT_RECORD_WINDOWS = [ 10, 30, 50 ].freeze
  TEAM_PROFILE_GAME_COLUMNS = %i[
    id schedule_id mlb_id official_date scheduled_at game_type status detailed_status
    home_team_id away_team_id home_probable_pitcher_id away_probable_pitcher_id
    venue_name game_number doubleheader home_score away_score source_name source_url
    last_synced_at details_last_synced_at created_at updated_at
  ].freeze
  MIN_PITCHING_OUTS_FOR_RATE = 9
  TEAM_LEADER_DEFINITIONS = {
    batting: [
      { key: "WAR", label: "Wins above replacement", abbreviation: "WAR", aliases: %w[WAR war], direction: :desc },
      { key: "avg", label: "Batting average", abbreviation: "AVG", aliases: %w[avg AVG], direction: :desc, qualifier: :at_bats },
      { key: "ops", label: "On-base plus slugging", abbreviation: "OPS", aliases: %w[ops OPS], direction: :desc, qualifier: :at_bats },
      { key: "homeRuns", label: "Home runs", abbreviation: "HR", aliases: %w[homeRuns HR], direction: :desc },
      { key: "rbi", label: "Runs batted in", abbreviation: "RBI", aliases: %w[rbi RBI], direction: :desc }
    ],
    pitching: [
      { key: "WAR", label: "Wins above replacement", abbreviation: "WAR", aliases: %w[WAR war], direction: :desc },
      { key: "ERA", label: "Earned run average", abbreviation: "ERA", aliases: %w[ERA era], direction: :asc, qualifier: :innings },
      { key: "whip", label: "Walks and hits per inning", abbreviation: "WHIP", aliases: %w[whip WHIP], direction: :asc, qualifier: :innings },
      { key: "W", label: "Wins", abbreviation: "W", aliases: %w[W wins], direction: :desc },
      { key: "strikeOuts", label: "Strikeouts", abbreviation: "SO", aliases: %w[strikeOuts SO], direction: :desc }
    ]
  }.freeze
  TEAM_LEAGUES = {
    108 => "AL", 110 => "AL", 111 => "AL", 114 => "AL", 116 => "AL", 117 => "AL", 118 => "AL",
    133 => "AL", 136 => "AL", 139 => "AL", 140 => "AL", 141 => "AL", 142 => "AL", 145 => "AL", 147 => "AL",
    109 => "NL", 112 => "NL", 113 => "NL", 115 => "NL", 119 => "NL", 120 => "NL", 121 => "NL", 134 => "NL",
    135 => "NL", 137 => "NL", 138 => "NL", 143 => "NL", 144 => "NL", 146 => "NL", 158 => "NL"
  }.freeze

  def initialize(team:, season: nil, on: Date.current, user: nil, includes: [ "all" ])
    @team = team
    @requested_season = season
    @on = on
    @user = user
    @includes = Array(includes).map(&:to_s)
  end

  def result
    forty_man_roster = serialized_forty_man_roster
    active_roster = serialized_active_roster

    {
      season: season,
      available_seasons: available_seasons,
      record: record,
      division_rank: division_rank,
      roster: forty_man_roster,
      rosters: {
        forty_man: forty_man_roster,
        active: active_roster
      },
      roster_as_of: roster_reference_date,
      roster_summary: roster_summary(forty_man_roster, active_roster),
      recent_games: recent_games.map { |game| GameSerializer.call(game) },
      upcoming_games: upcoming_games.map { |game| GameSerializer.call(game) },
      **schedule_payload,
      **player_stats_payload,
      **team_stats_payload,
      team_stats_summary: team_stats_summary,
      **opponent_payload,
      **lineup_payload,
      team_leaders: team_leaders,
      source_metadata: source_metadata,
      performance_dashboard: performance_dashboard
    }
  end

  private

  attr_reader :team, :requested_season, :on, :user, :includes

  def opponent_payload
    return {} unless include_section?("opponent")

    {
      opponent_preparation: OpponentPreparationQuery.new(
        team: team,
        upcoming_games: upcoming_games,
        season: season,
        on: on
      ).result,
      opponent_reports: opponent_report_summaries
    }
  end

  def lineup_payload
    return {} unless include_section?("lineup")

    { lineup_scenarios: lineup_scenario_summaries }
  end

  def schedule_payload
    return {} unless include_section?("schedule")

    {
      schedule_games: schedule_games.map { |game| GameSerializer.call(game, include_schedule: false) }
    }
  end

  def player_stats_payload
    return {} unless include_section?("player-stats")

    {
      player_stats: {
        season: season,
        batting: player_stats_category("batting"),
        pitching: player_stats_category("pitching")
      }
    }
  end

  def player_stats_category(category)
    definitions = PlayerSeasonStatsLeaderboardQuery::COLUMN_DEFINITIONS_BY_CATEGORY.fetch(category)
    rows = PlayerSeasonStat
      .joins(:stat_type)
      .where(team: team, season: season, scope_type: "team", stat_types: { category: category })
      .includes(player: :profile)
      .to_a

    {
      columns: definitions.map { |definition| { key: definition.fetch(:key), label: definition.fetch(:label) } },
      players: rows.group_by(&:player).sort_by { |player, _| [ player.last_name.to_s, player.first_name.to_s ] }.map do |player, player_rows|
        {
          player: {
            id: player.id,
            mlb_id: player.mlb_id,
            full_name: player.full_name,
            first_name: player.first_name,
            last_name: player.last_name,
            headshot_url: player.profile&.headshot_url
          },
          stats: definitions.each_with_object({}) do |definition, stats|
            stat = definition.fetch(:aliases).filter_map do |alias_name|
              player_rows.find { |row| row.stat_type.name == alias_name }
            end.first
            stats[definition.fetch(:key)] = stat&.value&.to_s
          end
        }
      end
    }
  end

  def team_stats_payload
    return {} unless include_section?("team-stats")

    {
      team_stats: {
        season: season,
        batting: team_stats_category("batting"),
        pitching: team_stats_category("pitching")
      }
    }
  end

  def team_stats_category(category)
    definitions = PlayerSeasonStatsLeaderboardQuery::COLUMN_DEFINITIONS_BY_CATEGORY.fetch(category).reject { |definition| definition.fetch(:key) == "WAR" }
    official_stats_by_team = official_team_stats(category)

    {
      columns: definitions.map { |definition| { key: definition.fetch(:key), label: definition.fetch(:label) } },
      teams: Team.where(mlb_id: TEAM_LEAGUES.keys).order(:name).map do |current_team|
        {
          team: {
            id: current_team.id,
            mlb_id: current_team.mlb_id,
            name: current_team.name,
            team_name: current_team.team_name,
            abbreviation: current_team.abbreviation,
            league: TEAM_LEAGUES[current_team.mlb_id]
          },
          stats: definitions.each_with_object({}) do |definition, stats|
            value = official_stats_by_team.dig(current_team.mlb_id, definition.fetch(:key))
            stats[definition.fetch(:key)] = value.to_s if value.present?
          end
        }
      end
    }
  end

  def team_stats_summary
    batting = official_team_stats("batting")
    pitching = official_team_stats("pitching")

    {
      season: season,
      batting: {
        avg: ranked_team_stat(batting, "avg", :desc),
        homeRuns: ranked_team_stat(batting, "homeRuns", :desc)
      },
      pitching: {
        ERA: ranked_team_stat(pitching, "ERA", :asc)
      }
    }
  end

  def official_team_stats(category)
    @official_team_stats ||= {}
    @official_team_stats[category] ||= MlbTeamStatsDownloader.call(season: season, category: category)
  end

  def ranked_team_stat(stats_by_team, key, direction)
    current_stats = stats_by_team[team.mlb_id]
    value = current_stats&.[](key)
    return { value: value, rank: nil } if value.blank?

    current_value = value.to_f
    better_count = stats_by_team.values.count do |stats|
      candidate = stats[key]
      next false if candidate.blank?

      direction == :desc ? candidate.to_f > current_value : candidate.to_f < current_value
    end

    { value: value, rank: better_count + 1 }
  end

  def include_section?(section)
    includes.include?("all") || includes.include?(section)
  end

  def opponent_report_summaries
    accessible_workflows(team.opponent_reports).includes(:owner, :opponent_team).where(season: season).recent_first.limit(5).map do |report|
      {
        id: report.id,
        owner: serialize_workflow_owner(report.owner),
        title: report.title,
        season: report.season,
        series_starts_on: report.series_starts_on,
        series_ends_on: report.series_ends_on,
        generated_at: report.generated_at,
        opponent: {
          id: report.opponent_team.id,
          mlb_id: report.opponent_team.mlb_id,
          name: report.opponent_team.name,
          abbreviation: report.opponent_team.abbreviation
        },
        probable_starter_count: Array(report.snapshot["probable_starters"]).length
      }
    end
  end

  def lineup_scenario_summaries
    accessible_workflows(team.lineup_scenarios).includes(:owner).where(season: season).order(scenario_date: :desc, created_at: :desc).limit(5).map do |scenario|
      {
        id: scenario.id,
        owner: serialize_workflow_owner(scenario.owner),
        name: scenario.name,
        scenario_date: scenario.scenario_date,
        validated_at: scenario.validated_at,
        entry_count: scenario.entries.count,
        evaluation_inputs: scenario.evaluation_inputs || {},
        total_score: scenario.total_score&.to_f,
        score_breakdown: scenario.score_breakdown || {}
      }
    end
  end

  def accessible_workflows(relation)
    OwnedWorkflowPolicy::Scope.new(user, relation).resolve
  end

  def serialize_workflow_owner(owner)
    { id: owner.id, name: owner.name, email: owner.email, role: owner.role }
  end

  def season
    @season ||= Integer(requested_season, exception: false) || stored_seasons.max || on.year
  end

  def available_seasons
    @available_seasons ||= (stored_seasons + [ season ]).uniq.sort
  end

  def stored_seasons
    @stored_seasons ||= team_games.joins(:schedule).distinct.order("schedules.season").pluck("schedules.season")
  end

  def team_games
    @team_games ||= Game.for_team(team)
  end

  def season_games
    @season_games ||= team_games
      .joins(:schedule)
      .where(schedules: { season: season })
      .select(*TEAM_PROFILE_GAME_COLUMNS)
  end

  def completed_games
    @completed_games ||= season_games
      .where(status: "final")
      .where("official_date <= ?", on)
      .where.not(home_score: nil, away_score: nil)
      .order(official_date: :desc, scheduled_at: :desc, mlb_id: :desc)
      .preload(:home_team, :away_team)
      .to_a
  end

  def record
    record_for_games(completed_games).merge(
      recent: RECENT_RECORD_WINDOWS.index_with { |window| record_for_games(completed_games.first(window)) }
    )
  end

  def record_for_games(games)
    totals = games.each_with_object({ wins: 0, losses: 0, ties: 0, runs_scored: 0, runs_allowed: 0 }) do |game, sum|
      team_score, opponent_score = scores_for(game)
      sum[:runs_scored] += team_score
      sum[:runs_allowed] += opponent_score

      if team_score > opponent_score
        sum[:wins] += 1
      elsif team_score < opponent_score
        sum[:losses] += 1
      else
        sum[:ties] += 1
      end
    end

    totals.merge(games_played: games.length, winning_percentage: winning_percentage(totals))
  end

  def division_rank
    StandingsSnapshotQuery.new(season: season).division_rank_for(team)
  end

  def team_leaders
    TEAM_LEADER_DEFINITIONS.to_h do |category, definitions|
      [ category, definitions.map { |definition| team_leader(definition, category) } ]
    end
  end

  def team_leader(definition, category)
    candidates = leader_stat_rows.group_by(&:player).filter_map do |player, rows|
      stat = definition.fetch(:aliases).filter_map do |alias_name|
        rows.find { |row| row.stat_type.name == alias_name && row.stat_type.category == category.to_s }
      end.first
      next unless stat
      next unless qualified_team_leader?(rows, definition[:qualifier])

      [ player, stat.value ]
    end
    player, value = candidates.public_send(definition.fetch(:direction) == :asc ? :min_by : :max_by) do |candidate|
      [ candidate.last, candidate.first.last_name, candidate.first.first_name ]
    end

    {
      key: definition.fetch(:key),
      label: definition.fetch(:label),
      abbreviation: definition.fetch(:abbreviation),
      value: value&.to_s("F"),
      player: player && {
        id: player.id,
        mlb_id: player.mlb_id,
        full_name: player.full_name,
        first_name: player.first_name,
        last_name: player.last_name,
        headshot_url: player.profile&.headshot_url
      }
    }
  end

  def qualified_team_leader?(rows, qualifier)
    case qualifier
    when :at_bats
      leader_stat_value(rows, %w[atBats AB]).to_f >= [ (completed_games.length * 2.7).floor, 1 ].max
    when :innings
      innings_outs(leader_stat_value(rows, %w[inningsPitched IP])) >= [ completed_games.length, 1 ].max * 3
    else
      true
    end
  end

  def leader_stat_value(rows, aliases)
    aliases.each do |name|
      row = rows.find { |candidate| candidate.stat_type.name == name }
      return row.value if row
    end
    nil
  end

  def leader_stat_rows
    @leader_stat_rows ||= PlayerSeasonStat
      .joins(:stat_type)
      .where(team: team, season: season, stat_types: { name: team_leader_stat_names })
      .includes(:stat_type, player: :profile)
      .to_a
  end

  def team_leader_stat_names
    @team_leader_stat_names ||= (
      TEAM_LEADER_DEFINITIONS.values.flatten.flat_map { |definition| definition.fetch(:aliases) } +
      %w[atBats AB inningsPitched IP]
    ).uniq
  end

  def innings_outs(value)
    decimal = BigDecimal(value.to_s)
    whole = decimal.floor
    partial = ((decimal - whole) * 10).round
    (whole * 3) + partial
  rescue ArgumentError
    0
  end

  def scores_for(game)
    game.home_team_id == team.id ? [ game.home_score, game.away_score ] : [ game.away_score, game.home_score ]
  end

  def winning_percentage(totals)
    decisions = totals[:wins] + totals[:losses]
    return nil if decisions.zero?

    (totals[:wins].to_f / decisions).round(3)
  end

  def recent_games
    @recent_games ||= season_games
      .where(status: "final")
      .where("official_date <= ?", on)
      .where.not(home_score: nil, away_score: nil)
      .order(official_date: :desc, scheduled_at: :desc, mlb_id: :desc)
      .limit(GAME_LIMIT)
      .preload(:schedule, :home_team, :away_team, :home_probable_pitcher, :away_probable_pitcher)
      .to_a
  end

  def upcoming_games
    @upcoming_games ||= season_games
      .where("official_date >= ?", on)
      .where(home_score: nil, away_score: nil)
      .order(:official_date, :scheduled_at, :mlb_id)
      .limit(GAME_LIMIT)
      .preload(:schedule, :home_team, :away_team, :home_probable_pitcher, :away_probable_pitcher)
      .to_a
  end

  def schedule_games
    @schedule_games ||= season_games
      .order(:official_date, :scheduled_at, :mlb_id)
      .preload(:home_team, :away_team, :home_probable_pitcher, :away_probable_pitcher)
      .to_a
  end

  def roster_memberships
    @roster_memberships ||= begin
      memberships = team.team_memberships.active_on(roster_reference_date)
      memberships = memberships.where(player_id: season_roster.player_ids) if matching_season_roster?

      memberships
      .includes(player: [ :profile, { player_positions: :position } ])
      .to_a
      .group_by(&:player_id)
      .values
      .map { |memberships| memberships.min_by { |membership| [ MlbRosterStatus.priority(membership.roster_status), -membership.starts_on.jd, membership.id ] } }
      .sort_by { |membership| [ membership.primary_position.to_s, membership.player.last_name, membership.player.first_name ] }
    end
  end

  def season_roster
    return @season_roster if defined?(@season_roster)

    @season_roster = team.rosters.includes(:roster_players).find_by(season: season)
  end

  def roster_reference_date
    @roster_reference_date ||= if season < on.year
      season_games.maximum(:official_date) || Date.new(season, 12, 31)
    else
      season_roster&.snapshot_on || on
    end
  end

  def matching_season_roster?
    season_roster&.snapshot_on == roster_reference_date
  end

  def roster_snapshot(roster_type)
    @roster_snapshots ||= {}
    @roster_snapshots[roster_type] ||= team.roster_snapshots
      .includes(roster_snapshot_players: { player: :profile })
      .find_by(season: season, snapshot_on: roster_reference_date, roster_type: roster_type)
  end

  def serialized_forty_man_roster
    snapshot = roster_snapshot("40Man")
    return serialize_roster_snapshot(snapshot) if snapshot

    roster_memberships.map { |membership| serialize_membership(membership) }
  end

  def serialized_active_roster
    snapshot = roster_snapshot("active")
    return serialize_roster_snapshot(snapshot) if snapshot

    active_roster_memberships.map { |membership| serialize_membership(membership) }
  end

  def serialize_roster_snapshot(snapshot)
    snapshot.roster_snapshot_players
      .sort_by { |entry| [ entry.position_code.to_s, entry.full_name ] }
      .map { |entry| serialize_roster_snapshot_player(entry) }
  end

  def serialize_roster_snapshot_player(entry)
    player = entry.player
    normalized_status = MlbRosterStatus.normalize(code: entry.status_code, description: entry.status_description)

    {
      id: "snapshot-#{entry.id}",
      roster_status: normalized_status,
      status_description: entry.status_description,
      injured: MlbRosterStatus.injured?(normalized_status),
      jersey_number: entry.jersey_number,
      primary_position: entry.position_code,
      pitching_role: pitching_role_for(player),
      starts_on: nil,
      last_synced_at: entry.roster_snapshot.last_synced_at,
      player: {
        id: player&.id,
        mlb_id: entry.mlb_id,
        full_name: entry.full_name,
        first_name: entry.first_name,
        last_name: entry.last_name,
        headshot_url: player&.profile&.headshot_url
      }
    }
  end

  def serialize_membership(membership)
    player = membership.player
    profile = player.profile
    position = membership.primary_position.presence || current_primary_position(player)&.abbreviation

    {
      id: membership.id,
      roster_status: membership.roster_status,
      status_description: membership.source_status_description,
      injured: membership.injured?,
      jersey_number: membership.jersey_number,
      primary_position: position,
      pitching_role: pitching_role_for(player),
      starts_on: membership.starts_on,
      last_synced_at: membership.last_synced_at,
      player: {
        id: player.id,
        mlb_id: player.mlb_id,
        full_name: player.full_name,
        first_name: player.first_name,
        last_name: player.last_name,
        headshot_url: profile&.headshot_url
      }
    }
  end

  def active_roster_memberships
    @active_roster_memberships ||= roster_memberships.select do |membership|
      membership.roster_status.to_s.casecmp("active").zero?
    end
  end

  def current_primary_position(player)
    player.player_positions.find { |assignment| assignment.season.nil? && assignment.is_primary? }&.position
  end

  def pitching_role_for(player)
    return nil unless player

    row = aggregate_player_rows(team_player_pitching_rows).find { |entry| entry[:player]&.id == player.id }
    return nil unless row

    row[:games_started].positive? ? "starter" : "reliever"
  end

  def roster_summary(forty_man_roster, active_roster)
    {
      total: forty_man_roster.length,
      active: active_roster.length,
      injured: forty_man_roster.count { |entry| entry[:injured] },
      other: forty_man_roster.count { |entry| entry[:roster_status] != "active" && !entry[:injured] }
    }
  end

  def source_metadata
    game_sync = team_games.maximum(:last_synced_at)
    roster_sync = roster_snapshot("40Man")&.last_synced_at ||
      (season_roster&.last_synced_at if matching_season_roster?) ||
      roster_memberships.filter_map(&:last_synced_at).max
    analytics_sync = team_daily_metrics.maximum(:calculated_at)

    {
      last_updated_at: [ game_sync, roster_sync, analytics_sync, team.updated_at ].compact.max,
      schedule_last_synced_at: game_sync,
      roster_last_synced_at: roster_sync,
      analytics_last_calculated_at: analytics_sync,
      sources: [
        ("MLB Stats API" if game_sync.present? || roster_sync.present?),
        ("NineLens daily analytics" if analytics_sync.present?)
      ].compact
    }
  end

  def performance_dashboard
    {
      rankings: rankings_payload,
      recent_form: recent_form_payload,
      home_road_splits: home_road_splits_payload,
      platoon_splits: platoon_splits_payload,
      starter_bullpen: starter_bullpen_payload,
      one_run_performance: one_run_performance_payload,
      analytics_coverage: analytics_coverage_payload,
      strengths: strengths_payload,
      concerns: concerns_payload,
      drill_down: drill_down_payload
    }
  end

  def rankings_payload
    team_totals = team_totals_index
    current = team_totals[team.id] || {}

    {
      offense: {
        ops: ranking_entry(team_totals, team.id, :ops, descending: true),
        runs_per_game: ranking_entry(team_totals, team.id, :runs_per_game, descending: true),
        home_runs: ranking_entry(team_totals, team.id, :home_runs, descending: true),
        batting_average: ranking_entry(team_totals, team.id, :batting_average, descending: true),
        stolen_bases: ranking_entry(team_totals, team.id, :stolen_bases, descending: true),
        strikeout_rate: ranking_entry(team_totals, team.id, :strikeout_rate, descending: false),
        walk_rate: ranking_entry(team_totals, team.id, :walk_rate, descending: true)
      },
      pitching: {
        era: ranking_entry(team_totals, team.id, :era, descending: false),
        whip: ranking_entry(team_totals, team.id, :whip, descending: false),
        saves: ranking_entry(team_totals, team.id, :pitching_saves, descending: true),
        strikeouts: ranking_entry(team_totals, team.id, :pitching_strikeouts, descending: true),
        quality_starts: ranking_entry(team_totals, team.id, :pitching_quality_starts, descending: true),
        strikeout_rate: ranking_entry(team_totals, team.id, :pitching_strikeout_rate, descending: true),
        walk_rate: ranking_entry(team_totals, team.id, :pitching_walk_rate, descending: false)
      },
      context: {
        total_teams: team_totals.length,
        games: current[:games] || 0
      }
    }
  end

  def analytics_coverage_payload
    game_ids = completed_games.map(&:id)
    pitching_team_ids_by_game = GamePlayerPitchingLine
      .where(game_id: game_ids)
      .distinct
      .pluck(:game_id, :team_id)
      .group_by(&:first)
      .transform_values { |pairs| pairs.map(&:last) }

    missing_games = completed_games.filter_map do |game|
      present_team_ids = pitching_team_ids_by_game.fetch(game.id, [])
      missing_teams = [ game.away_team, game.home_team ].reject { |entry| present_team_ids.include?(entry.id) }
      next if missing_teams.empty?

      {
        id: game.id,
        mlb_id: game.mlb_id,
        official_date: game.official_date,
        matchup: "#{game.away_team.abbreviation} at #{game.home_team.abbreviation}",
        missing_teams: missing_teams.map { |entry| { id: entry.id, abbreviation: entry.abbreviation } }
      }
    end

    {
      complete: missing_games.empty?,
      completed_game_count: completed_games.length,
      complete_pitching_game_count: completed_games.length - missing_games.length,
      missing_game_count: missing_games.length,
      missing_games: missing_games
    }
  end

  def recent_form_payload
    RECENT_GAME_WINDOWS.to_h do |window|
      aggregate = aggregate_recent_window(window)
      [
        window.to_s,
        {
          requested_games: window,
          sampled_games: aggregate[:games],
          wins: aggregate[:wins],
          losses: aggregate[:losses],
          runs_scored: aggregate[:runs_scored],
          runs_allowed: aggregate[:runs_allowed],
          home_runs: aggregate[:home_runs],
          runs_per_game: aggregate[:runs_per_game],
          run_differential: aggregate[:run_differential],
          winning_percentage: ratio_or_nil(aggregate[:wins], aggregate[:wins] + aggregate[:losses]),
          ops: aggregate[:ops],
          era: aggregate[:era],
          whip: aggregate[:whip]
        }
      ]
    end
  end

  def home_road_splits_payload
    grouped = completed_games.group_by { |game| game.home_team_id == team.id ? :home : :road }
    {
      home: record_summary_for_games(grouped[:home] || []),
      road: record_summary_for_games(grouped[:road] || [])
    }
  end

  def platoon_splits_payload
    {
      offense: {
        vs_left: summarize_batter_split("pitcher_hand", "L"),
        vs_right: summarize_batter_split("pitcher_hand", "R")
      },
      pitching: {
        vs_left: summarize_pitcher_split("batter_hand", "L"),
        vs_right: summarize_pitcher_split("batter_hand", "R")
      }
    }
  end

  def starter_bullpen_payload
    rows = team_player_pitching_rows
    starters, relievers = rows.partition { |row| metric_number(row, :games_started).positive? }

    {
      starters: summarize_pitching_rows(starters),
      bullpen: summarize_pitching_rows(relievers)
    }
  end

  def one_run_performance_payload
    one_run_games = completed_games.select do |game|
      scored, allowed = scores_for(game)
      (scored - allowed).abs == 1
    end

    wins = one_run_games.count { |game| scores_for(game).first > scores_for(game).last }
    losses = one_run_games.count { |game| scores_for(game).first < scores_for(game).last }
    {
      games: one_run_games.length,
      wins: wins,
      losses: losses,
      winning_percentage: ratio_or_nil(wins, wins + losses)
    }
  end

  def strengths_payload
    entries = []
    offense_ops = rankings_payload.dig(:offense, :ops, :rank)
    pitching_era = rankings_payload.dig(:pitching, :era, :rank)
    one_run_wpct = one_run_performance_payload[:winning_percentage]

    if offense_ops && offense_ops <= 10
      entries << "Top-10 offense by OPS"
    end

    if pitching_era && pitching_era <= 10
      entries << "Top-10 pitching ERA"
    end

    if one_run_wpct && one_run_wpct >= 0.55
      entries << "Strong one-run game results"
    end

    recent = recent_form_payload["15"]
    season_ops = team_totals_index.dig(team.id, :ops)
    if recent && season_ops && recent[:ops] && recent[:ops] > season_ops
      entries << "Offense trending up over the last 15 games"
    end

    entries.presence || [ "No standout strengths identified with current sample" ]
  end

  def concerns_payload
    entries = []
    offense_ops = rankings_payload.dig(:offense, :ops, :rank)
    pitching_era = rankings_payload.dig(:pitching, :era, :rank)
    total_teams = rankings_payload.dig(:context, :total_teams).to_i

    if offense_ops && total_teams.positive? && offense_ops >= (total_teams - 9)
      entries << "Bottom-third offense by OPS"
    end

    if pitching_era && total_teams.positive? && pitching_era >= (total_teams - 9)
      entries << "Bottom-third pitching ERA"
    end

    recent = recent_form_payload["30"]
    season = team_totals_index[team.id] || {}
    if recent && season[:era] && recent[:era] && recent[:era] > (season[:era] * 1.15)
      entries << "Run prevention has slipped in the last 30 games"
    end

    if recent && season[:ops] && recent[:ops] && recent[:ops] < (season[:ops] * 0.9)
      entries << "Offense has cooled over the last 30 games"
    end

    entries.presence || [ "No major concerns flagged from current indicators" ]
  end

  def drill_down_payload
    {
      games: recent_games.first(10).map { |game| drill_game(game) },
      players: {
        hitters: top_hitters,
        pitchers: top_pitchers
      },
      plate_appearances: {
        team_total: team_player_batting_rows.sum { |row| metric_number(row, :plate_appearances) },
        leaders: top_plate_appearance_leaders
      },
      pitches: {
        team_total: team_player_pitching_rows.sum { |row| metric_number(row, :pitches) },
        leaders: top_pitch_volume_leaders
      }
    }
  end

  def drill_game(game)
    {
      id: game.id,
      official_date: game.official_date,
      mlb_id: game.mlb_id,
      opponent: game.home_team_id == team.id ? game.away_team.abbreviation : game.home_team.abbreviation,
      result: result_for(game),
      score: {
        team: scores_for(game).first,
        opponent: scores_for(game).last
      },
      drill_down: {
        game_id: game.id,
        game_mlb_id: game.mlb_id
      }
    }
  end

  def top_hitters
    aggregate_player_rows(team_player_batting_rows)
      .map { |row| row.merge(ops: calculate_ops(row), batting_average: ratio_or_nil(row[:hits], row[:at_bats])) }
      .sort_by { |row| [ -(row[:ops] || -1), -row[:plate_appearances] ] }
      .first(5)
      .map { |row| serialize_player_row(row, :hitter) }
  end

  def top_pitchers
    aggregate_player_rows(team_player_pitching_rows)
      .map { |row| row.merge(era: calculate_era(row), whip: calculate_whip(row)) }
      .select { |row| row[:outs_recorded] >= MIN_PITCHING_OUTS_FOR_RATE }
      .sort_by { |row| [ row[:era] || 99, -(row[:outs_recorded] || 0) ] }
      .first(5)
      .map { |row| serialize_player_row(row, :pitcher) }
  end

  def top_plate_appearance_leaders
    aggregate_player_rows(team_player_batting_rows)
      .sort_by { |row| -row[:plate_appearances] }
      .first(5)
      .map do |row|
        {
          player: serialize_player_identity(row[:player]),
          plate_appearances: row[:plate_appearances],
          at_bats: row[:at_bats],
          hits: row[:hits],
          drill_down: { player_id: row[:player]&.id }
        }
      end
  end

  def top_pitch_volume_leaders
    aggregate_player_rows(team_player_pitching_rows)
      .sort_by { |row| -row[:pitches] }
      .first(5)
      .map do |row|
        {
          player: serialize_player_identity(row[:player]),
          pitches: row[:pitches],
          batters_faced: row[:batters_faced],
          strikeouts: row[:strikeouts],
          drill_down: { player_id: row[:player]&.id }
        }
      end
  end

  def serialize_player_row(row, role)
    {
      player: serialize_player_identity(row[:player]),
      role: role,
      plate_appearances: row[:plate_appearances],
      hits: row[:hits],
      home_runs: row[:home_runs],
      ops: row[:ops],
      innings_pitched: innings_from_outs(row[:outs_recorded]),
      era: row[:era],
      whip: row[:whip],
      strikeouts: row[:strikeouts],
      drill_down: { player_id: row[:player]&.id }
    }
  end

  def serialize_player_identity(player)
    return nil unless player

    {
      id: player.id,
      mlb_id: player.mlb_id,
      full_name: player.full_name
    }
  end

  def result_for(game)
    team_score, opponent_score = scores_for(game)
    return "T" if team_score == opponent_score

    team_score > opponent_score ? "W" : "L"
  end

  def team_totals_index
    @team_totals_index ||= begin
      rows = TeamDailyMetric
        .where(metric_date: season_date_range)
        .where(calculation_version: analytics_version)
        .includes(:team)
        .to_a
      rows_by_team = rows.group_by(&:team_id)
      totals_by_team = rows_by_team.transform_values { |team_rows| summarize_team_rows(team_rows) }

      # Older analytics rows did not persist stolen bases. Replace that total
      # from the source batting lines until the full season has been recalculated.
      legacy_team_ids = rows_by_team.filter_map do |team_id, team_rows|
        team_id if team_rows.any? { |row| !row.metrics.key?("stolen_bases") }
      end
      if legacy_team_ids.any?
        stolen_bases_by_team = GamePlayerBattingLine
          .joins(:game)
          .where(team_id: legacy_team_ids, games: { official_date: season_date_range })
          .group(:team_id)
          .sum(:stolen_bases)
        legacy_team_ids.each do |team_id|
          totals_by_team.fetch(team_id)[:stolen_bases] = stolen_bases_by_team.fetch(team_id, 0).to_f
        end
      end

      legacy_pitching_team_ids = rows_by_team.filter_map do |team_id, team_rows|
        team_id if team_rows.any? do |row|
          !row.metrics.key?("pitching_saves") || !row.metrics.key?("pitching_quality_starts")
        end
      end
      if legacy_pitching_team_ids.any?
        pitching_lines = GamePlayerPitchingLine
          .joins(:game)
          .where(team_id: legacy_pitching_team_ids, games: { official_date: season_date_range })
        saves_by_team = pitching_lines.group(:team_id).sum(:saves)
        quality_starts_by_team = pitching_lines
          .where(starter: true, outs_recorded: 18..)
          .where(earned_runs: ..3)
          .group(:team_id)
          .count

        legacy_pitching_team_ids.each do |team_id|
          totals_by_team.fetch(team_id)[:pitching_saves] = saves_by_team.fetch(team_id, 0).to_f
          totals_by_team.fetch(team_id)[:pitching_quality_starts] = quality_starts_by_team.fetch(team_id, 0).to_f
        end
      end

      totals_by_team
    end
  end

  def team_daily_metrics
    @team_daily_metrics ||= TeamDailyMetric
      .where(team_id: team.id, metric_date: season_date_range)
      .where(calculation_version: analytics_version)
      .order(:metric_date)
      .to_a
  end

  def analytics_version
    @analytics_version ||= TeamDailyMetric
      .where(metric_date: season_date_range)
      .order(calculated_at: :desc)
      .pick(:calculation_version)
  end

  def season_start_date
    @season_start_date ||= Date.new(season, 1, 1)
  end

  def season_end_date
    @season_end_date ||= [ on, Date.new(season, 12, 31) ].min
  end

  def season_date_range
    season_start_date..season_end_date
  end

  def summarize_team_rows(rows)
    totals = {
      games: 0,
      wins: 0,
      losses: 0,
      ties: 0,
      runs_scored: 0,
      runs_allowed: 0,
      plate_appearances: 0,
      at_bats: 0,
      hits: 0,
      doubles: 0,
      triples: 0,
      home_runs: 0,
      stolen_bases: 0,
      walks: 0,
      strikeouts: 0,
      hit_by_pitch: 0,
      sacrifice_flies: 0,
      pitching_outs_recorded: 0,
      pitching_batters_faced: 0,
      pitching_hits_allowed: 0,
      pitching_earned_runs: 0,
      pitching_walks: 0,
      pitching_strikeouts: 0,
      pitching_saves: 0,
      pitching_quality_starts: 0
    }

    rows.each do |row|
      totals.keys.each do |key|
        totals[key] += metric_number(row, key)
      end
    end

    ops = calculate_ops(totals)
    era = totals[:pitching_outs_recorded].positive? ? round((totals[:pitching_earned_runs] * 27.0) / totals[:pitching_outs_recorded]) : nil
    whip = totals[:pitching_outs_recorded].positive? ? round(((totals[:pitching_hits_allowed] + totals[:pitching_walks]) * 3.0) / totals[:pitching_outs_recorded]) : nil

    totals.merge(
      run_differential: totals[:runs_scored] - totals[:runs_allowed],
      winning_percentage: ratio_or_nil(totals[:wins], totals[:wins] + totals[:losses]),
      runs_per_game: ratio_or_nil(totals[:runs_scored], totals[:games]),
      batting_average: ratio_or_nil(totals[:hits], totals[:at_bats]),
      ops: ops,
      era: era,
      whip: whip,
      strikeout_rate: ratio_or_nil(totals[:strikeouts], totals[:plate_appearances]),
      walk_rate: ratio_or_nil(totals[:walks], totals[:plate_appearances]),
      pitching_strikeout_rate: ratio_or_nil(totals[:pitching_strikeouts], totals[:pitching_batters_faced]),
      pitching_walk_rate: ratio_or_nil(totals[:pitching_walks], totals[:pitching_batters_faced])
    )
  end

  def aggregate_recent_window(game_target)
    selected = []
    total_games = 0
    team_daily_metrics.reverse_each do |row|
      break if total_games >= game_target

      selected << row
      total_games += metric_number(row, :games)
    end

    summary = summarize_team_rows(selected)
    return summary if summary[:ops].present? && summary[:era].present? && summary[:whip].present?

    fallback = summarize_recent_game_lines(game_target)
    summary.merge(
      ops: summary[:ops].presence || fallback[:ops],
      era: summary[:era].presence || fallback[:era],
      whip: summary[:whip].presence || fallback[:whip]
    )
  end

  def summarize_recent_game_lines(game_target)
    games = season_games
      .where("official_date <= ?", on)
      .where.not(home_score: nil, away_score: nil)
      .order(official_date: :desc, scheduled_at: :desc, mlb_id: :desc)
      .limit(game_target)
      .to_a
    return { ops: nil, era: nil, whip: nil } if games.empty?

    game_ids = games.map(&:id)
    batting_totals = GamePlayerBattingLine
      .where(team_id: team.id, game_id: game_ids)
      .pluck(:at_bats, :hits, :doubles, :triples, :home_runs, :walks)
      .each_with_object({ at_bats: 0, hits: 0, doubles: 0, triples: 0, home_runs: 0, walks: 0 }) do |values, sum|
        sum[:at_bats] += values[0].to_i
        sum[:hits] += values[1].to_i
        sum[:doubles] += values[2].to_i
        sum[:triples] += values[3].to_i
        sum[:home_runs] += values[4].to_i
        sum[:walks] += values[5].to_i
      end

    pitching_totals = GamePlayerPitchingLine
      .where(team_id: team.id, game_id: game_ids)
      .pluck(:outs_recorded, :hits, :earned_runs, :walks)
      .each_with_object({ outs_recorded: 0, hits: 0, earned_runs: 0, walks: 0 }) do |values, sum|
        sum[:outs_recorded] += values[0].to_i
        sum[:hits] += values[1].to_i
        sum[:earned_runs] += values[2].to_i
        sum[:walks] += values[3].to_i
      end

    {
      ops: calculate_ops(batting_totals),
      era: calculate_era(pitching_totals),
      whip: calculate_whip(pitching_totals)
    }
  end

  def ranking_entry(team_totals, team_id, metric_key, descending:)
    values = team_totals.filter_map do |id, metrics|
      value = metrics[metric_key]
      next if value.nil?

      [ id, value ]
    end
    return { rank: nil, value: nil, percentile: nil } if values.empty?

    team_value = team_totals.dig(team_id, metric_key)
    return { rank: nil, value: nil, percentile: nil } if team_value.nil?

    rank = values.count do |id, value|
      next false if id == team_id

      descending ? value > team_value : value < team_value
    end + 1

    {
      rank: rank,
      value: team_value,
      percentile: round(((values.length - rank + 1).to_f / values.length) * 100)
    }
  end

  def record_summary_for_games(games)
    wins = 0
    losses = 0
    ties = 0
    runs_scored = 0
    runs_allowed = 0

    games.each do |game|
      scored, allowed = scores_for(game)
      runs_scored += scored
      runs_allowed += allowed
      if scored > allowed
        wins += 1
      elsif scored < allowed
        losses += 1
      else
        ties += 1
      end
    end

    {
      games: games.length,
      wins: wins,
      losses: losses,
      ties: ties,
      runs_scored: runs_scored,
      runs_allowed: runs_allowed,
      run_differential: runs_scored - runs_allowed,
      winning_percentage: ratio_or_nil(wins, wins + losses)
    }
  end

  def summarize_batter_split(split_type, split_value)
    rows = BatterSplitSummary
      .where(team_id: team.id, split_type: split_type, split_value: split_value)
      .where(metric_date: season_date_range, calculation_version: analytics_version)
      .to_a

    plate_appearances = rows.sum { |row| metric_number(row, :plate_appearances) }
    pitches_seen = rows.sum { |row| metric_number(row, :pitches_seen) }
    hits = rows.sum { |row| metric_number(row, :hits) }
    walks = rows.sum { |row| metric_number(row, :walks) }
    strikeouts = rows.sum { |row| metric_number(row, :strikeouts) }
    batted_balls = rows.sum { |row| metric_number(row, :batted_balls) }
    hard_hit_sum = rows.sum do |row|
      (metric_number(row, :hard_hit_percentage) / 100.0) * metric_number(row, :batted_balls)
    end

    {
      sample_size: plate_appearances,
      pitches_seen: pitches_seen,
      batting_average: ratio_or_nil(hits, [ plate_appearances - walks, 1 ].max),
      strikeout_rate: ratio_or_nil(strikeouts, plate_appearances),
      walk_rate: ratio_or_nil(walks, plate_appearances),
      hard_hit_rate: ratio_or_nil(hard_hit_sum, batted_balls),
      average_exit_velocity: weighted_average(rows, :average_exit_velocity, :exit_velocity_sample_size)
    }
  end

  def summarize_pitcher_split(split_type, split_value)
    rows = PitcherSplitSummary
      .where(team_id: team.id, split_type: split_type, split_value: split_value)
      .where(metric_date: season_date_range, calculation_version: analytics_version)
      .to_a

    batters_faced = rows.sum { |row| metric_number(row, :batters_faced) }
    pitch_count = rows.sum { |row| metric_number(row, :pitch_count) }
    strikeouts = rows.sum { |row| metric_number(row, :strikeouts) }
    walks = rows.sum { |row| metric_number(row, :walks) }
    whiffs = rows.sum { |row| metric_number(row, :whiffs) }
    swings = rows.sum { |row| metric_number(row, :swings) }

    {
      sample_size: batters_faced,
      pitch_count: pitch_count,
      strikeout_rate: ratio_or_nil(strikeouts, batters_faced),
      walk_rate: ratio_or_nil(walks, batters_faced),
      whiff_rate: ratio_or_nil(whiffs, swings),
      average_velocity: weighted_average(rows, :average_velocity, :velocity_sample_size)
    }
  end

  def summarize_pitching_rows(rows)
    totals = aggregate_player_rows(rows).each_with_object({
      outs_recorded: 0,
      batters_faced: 0,
      pitches: 0,
      hits: 0,
      earned_runs: 0,
      walks: 0,
      strikeouts: 0,
      games_started: 0,
      games: 0
    }) do |row, sum|
      sum[:outs_recorded] += row[:outs_recorded]
      sum[:batters_faced] += row[:batters_faced]
      sum[:pitches] += row[:pitches]
      sum[:hits] += row[:hits]
      sum[:earned_runs] += row[:earned_runs]
      sum[:walks] += row[:walks]
      sum[:strikeouts] += row[:strikeouts]
      sum[:games_started] += row[:games_started]
      sum[:games] += row[:games]
    end

    totals.merge(
      innings_pitched: innings_from_outs(totals[:outs_recorded]),
      era: calculate_era(totals),
      whip: calculate_whip(totals),
      strikeout_rate: ratio_or_nil(totals[:strikeouts], totals[:batters_faced]),
      walk_rate: ratio_or_nil(totals[:walks], totals[:batters_faced])
    )
  end

  def aggregate_player_rows(rows)
    rows.group_by(&:player).map do |player, entries|
      {
        player: player,
        plate_appearances: entries.sum { |row| metric_number(row, :plate_appearances) },
        at_bats: entries.sum { |row| metric_number(row, :at_bats) },
        hits: entries.sum { |row| metric_number(row, :hits) },
        doubles: entries.sum { |row| metric_number(row, :doubles) },
        triples: entries.sum { |row| metric_number(row, :triples) },
        home_runs: entries.sum { |row| metric_number(row, :home_runs) },
        walks: entries.sum { |row| metric_number(row, :walks) },
        strikeouts: entries.sum { |row| metric_number(row, :strikeouts) },
        outs_recorded: entries.sum { |row| metric_number(row, :outs_recorded) },
        batters_faced: entries.sum { |row| metric_number(row, :batters_faced) },
        pitches: entries.sum { |row| metric_number(row, :pitches) },
        earned_runs: entries.sum { |row| metric_number(row, :earned_runs) },
        games_started: entries.sum { |row| metric_number(row, :games_started) },
        games: entries.sum { |row| metric_number(row, :games) }
      }
    end
  end

  def team_player_batting_rows
    @team_player_batting_rows ||= PlayerBattingDaily
      .where(team_id: team.id, metric_date: season_date_range, calculation_version: analytics_version)
      .includes(:player)
      .to_a
  end

  def team_player_pitching_rows
    @team_player_pitching_rows ||= PlayerPitchingDaily
      .where(team_id: team.id, metric_date: season_date_range, calculation_version: analytics_version)
      .includes(:player)
      .to_a
  end

  def metric_number(row, key)
    row.metrics[key.to_s].to_f
  end

  def weighted_average(rows, metric_key, weight_key)
    total_weight = rows.sum { |row| metric_number(row, weight_key) }
    return nil if total_weight <= 0

    weighted_sum = rows.sum { |row| metric_number(row, metric_key) * metric_number(row, weight_key) }
    round(weighted_sum / total_weight)
  end

  def calculate_ops(metrics)
    at_bats = metrics[:at_bats].to_f
    hits = metrics[:hits].to_f
    walks = metrics[:walks].to_f
    hit_by_pitch = metrics[:hit_by_pitch].to_f
    sacrifice_flies = metrics[:sacrifice_flies].to_f
    doubles = metrics[:doubles].to_f
    triples = metrics[:triples].to_f
    home_runs = metrics[:home_runs].to_f
    total_bases = hits + doubles + (2 * triples) + (3 * home_runs)
    obp = ratio_or_nil(
      hits + walks + hit_by_pitch,
      at_bats + walks + hit_by_pitch + sacrifice_flies
    )
    slugging = ratio_or_nil(total_bases, at_bats)
    return nil if obp.nil? || slugging.nil?

    round(obp + slugging)
  end

  def calculate_era(metrics)
    outs = metrics[:outs_recorded].to_f
    return nil if outs <= 0

    round((metrics[:earned_runs].to_f * 27.0) / outs)
  end

  def calculate_whip(metrics)
    outs = metrics[:outs_recorded].to_f
    return nil if outs <= 0

    round(((metrics[:hits].to_f + metrics[:walks].to_f) * 3.0) / outs)
  end

  def ratio_or_nil(numerator, denominator)
    denom = denominator.to_f
    return nil if denom <= 0

    round(numerator.to_f / denom)
  end

  def innings_from_outs(outs)
    outs_value = outs.to_i
    (outs_value / 3) + ((outs_value % 3) / 10.0)
  end

  def round(value)
    value.to_f.round(4)
  end
end
