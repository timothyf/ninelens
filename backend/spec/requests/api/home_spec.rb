require "rails_helper"

RSpec.describe "Api::Home", type: :request do
  it "uses the Eastern calendar date during the UTC rollover window" do
    allow(Time).to receive(:current).and_return(Time.utc(2026, 7, 18, 3, 22))
    tigers = create_team(mlb_id: 116, name: "Detroit Tigers", abbreviation: "DET")
    guardians = create_team(mlb_id: 114, name: "Cleveland Guardians", abbreviation: "CLE")
    schedule = create_schedule(
      season: 2026,
      start_date: Date.new(2026, 3, 25),
      end_date: Date.new(2026, 9, 27)
    )
    eastern_today = create_game(
      schedule: schedule,
      official_date: Date.new(2026, 7, 17),
      scheduled_at: Time.utc(2026, 7, 17, 23, 10),
      home_team: tigers,
      away_team: guardians
    )
    create_game(
      schedule: schedule,
      official_date: Date.new(2026, 7, 18),
      scheduled_at: Time.utc(2026, 7, 18, 23, 10),
      home_team: guardians,
      away_team: tigers
    )

    get api_home_path

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", "as_of")).to eq("2026-07-17")
    expect(json_body.dig("data", "games").pluck("id")).to eq([ eastern_today.id ])
  end

  it "does not show an if-necessary postseason game after the series is complete" do
    rays = create_team(mlb_id: 139, name: "Tampa Bay Rays", abbreviation: "TB")
    yankees = create_team(mlb_id: 147, name: "New York Yankees", abbreviation: "NYY")
    schedule = create_schedule(season: 2026, schedule_type: "D", start_date: Date.new(2026, 10, 1), end_date: Date.new(2026, 10, 15))
    create_game(
      schedule:,
      official_date: ApplicationCalendar.current_date,
      home_team: yankees,
      away_team: rays,
      game_type: "D",
      status: "preview",
      raw_data: { "ifNecessary" => "Y", "seriesGameNumber" => 4 }
    )

    get api_home_path

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", "games")).to be_empty
  end

  it "returns the daily slate, qualified leaders, team pulse, and freshness metadata" do
    tigers = create_team(
      mlb_id: 116,
      name: "Detroit Tigers",
      abbreviation: "DET",
      team_name: "Tigers",
      location_name: "Detroit",
      short_name: "Detroit"
    )
    guardians = create_team(
      mlb_id: 114,
      name: "Cleveland Guardians",
      abbreviation: "CLE",
      team_name: "Guardians",
      location_name: "Cleveland",
      short_name: "Cleveland"
    )
    schedule = create_schedule(
      season: 2026,
      schedule_type: "R",
      start_date: Date.new(2026, 3, 25),
      end_date: Date.new(2026, 9, 27)
    )
    hitter = create_player(team: tigers, attributes: { mlb_id: 682_985, first_name: "Riley", last_name: "Greene" })
    pitcher = create_player(team: guardians, attributes: { mlb_id: 676_440, first_name: "Tanner", last_name: "Bibee" })

    game = create_game(
      schedule: schedule,
      official_date: Date.new(2026, 7, 16),
      scheduled_at: Time.zone.parse("2026-07-16T17:10:00Z"),
      status: "final",
      detailed_status: "Final",
      home_team: tigers,
      away_team: guardians,
      home_score: 5,
      away_score: 3,
      last_synced_at: Time.zone.parse("2026-07-16T20:30:00Z"),
      details_last_synced_at: Time.zone.parse("2026-07-16T20:31:00Z")
    )

    stat_types = {
      at_bats: create_stat_type(name: "atBats", label: "AB", category: "batting"),
      ops: create_stat_type(name: "ops", label: "OPS", category: "batting"),
      avg: create_stat_type(name: "avg", label: "AVG", category: "batting"),
      war: create_stat_type(name: "WAR", label: "WAR", category: "batting"),
      pitching_war: create_stat_type(name: "WAR", label: "WAR", category: "pitching"),
      home_runs: create_stat_type(name: "homeRuns", label: "HR", category: "batting"),
      rbi: create_stat_type(name: "rbi", label: "RBI", category: "batting"),
      innings: create_stat_type(name: "inningsPitched", label: "IP", category: "pitching"),
      wins: create_stat_type(name: "wins", label: "W", category: "pitching"),
      era: create_stat_type(name: "ERA", label: "ERA", category: "pitching"),
      strikeouts: create_stat_type(name: "strikeOuts", label: "SO", category: "pitching")
    }
    {
      at_bats: 10,
      ops: 1.050,
      avg: 0.333,
      war: 4.2,
      home_runs: 3,
      rbi: 12
    }.each do |key, value|
      create_player_season_stat(player: hitter, stat_type: stat_types.fetch(key), attributes: { team: tigers, season: 2026, value: value })
    end
    {
      innings: 5.0,
      wins: 1,
      era: 1.80,
      strikeouts: 9,
      pitching_war: 3.5
    }.each do |key, value|
      create_player_season_stat(player: pitcher, stat_type: stat_types.fetch(key), attributes: { team: guardians, season: 2026, value: value })
    end

    calculated_at = Time.zone.parse("2026-07-16T20:32:00Z")
    TeamDailyMetric.create!(
      team: tigers,
      metric_date: Date.new(2026, 7, 16),
      source_start_date: Date.new(2026, 7, 16),
      source_end_date: Date.new(2026, 7, 16),
      sample_size: 1,
      calculation_version: "v1",
      calculated_at: calculated_at,
      source_name: "NineLens daily analytics",
      metrics: { games: 1, wins: 1, losses: 0, runs_scored: 5, runs_allowed: 3 }
    )
    TeamDailyMetric.create!(
      team: guardians,
      metric_date: Date.new(2026, 7, 16),
      source_start_date: Date.new(2026, 7, 16),
      source_end_date: Date.new(2026, 7, 16),
      sample_size: 1,
      calculation_version: "v1",
      calculated_at: calculated_at,
      source_name: "NineLens daily analytics",
      metrics: { games: 1, wins: 0, losses: 1, runs_scored: 3, runs_allowed: 5 }
    )

    get api_home_path, params: { date: "2026-07-16" }

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", "season")).to eq(2026)
    expect(json_body.dig("data", "games", 0, "id")).to eq(game.id)
    expect(json_body.dig("data", "leaders").map { |leader| leader.fetch("key") }).to eq(%w[battingWAR ops avg homeRuns rbi pitchingWAR wins ERA strikeOuts])
    expect(json_body.dig("data", "leaders", 0, "entries", 0, "player", "full_name")).to eq("Riley Greene")
    expect(json_body.dig("data", "leaders", 4, "entries", 0, "player", "full_name")).to eq("Riley Greene")
    expect(json_body.dig("data", "leaders", 4, "entries", 0, "value")).to eq("12.0")
    expect(json_body.dig("data", "leaders", 5, "entries", 0, "player", "full_name")).to eq("Tanner Bibee")
    expect(json_body.dig("data", "leaders", 6, "entries", 0, "value")).to eq("1.0")
    expect(json_body.dig("data", "team_pulse", "best_records", 0, "team", "abbreviation")).to eq("DET")
    expect(json_body.dig("data", "team_pulse", "run_differential", 0, "run_differential")).to eq(2)
    expect(json_body.dig("data", "team_pulse", "last_30_form", 0)).to include(
      "recent_30_games" => 1,
      "recent_30_wins" => 1,
      "recent_30_losses" => 0
    )
    expect(json_body.dig("data", "freshness", "analytics")).to eq("2026-07-16T20:32:00.000Z")

    national_team = create_team(mlb_id: 109, name: "Arizona Diamondbacks", abbreviation: "ARI")
    national_hitter = create_player(team: national_team, attributes: { mlb_id: 700_001, first_name: "National", last_name: "Leader" })
    create_player_season_stat(
      player: national_hitter,
      stat_type: stat_types.fetch(:ops),
      attributes: { team: national_team, season: 2026, value: 1.2 }
    )
    create_player_season_stat(
      player: national_hitter,
      stat_type: stat_types.fetch(:at_bats),
      attributes: { team: national_team, season: 2026, value: 10 }
    )

    get api_home_path, params: { date: "2026-07-16", league: "national" }

    ops_leader = json_body.dig("data", "leaders")
      .find { |leader| leader.fetch("key") == "ops" }
      .fetch("entries")
      .first

    expect(ops_leader.dig("player", "full_name")).to eq("National Leader")
    expect(ops_leader.dig("team", "abbreviation")).to eq("ARI")
  end

  it "uses the last ten final games for recent form and ignores today's preview score" do
    tigers = create_team(mlb_id: 116, name: "Detroit Tigers", abbreviation: "DET")
    opponent = create_team(mlb_id: 108, name: "Los Angeles Angels", abbreviation: "LAA")
    schedule = create_schedule(season: 2026, start_date: Date.new(2026, 3, 25), end_date: Date.new(2026, 9, 27))
    calculated_at = Time.zone.parse("2026-07-19T12:00:00Z")

    10.times do |index|
      date = Date.new(2026, 7, 9) + index.days
      win = index >= 2
      create_game(
        schedule: schedule,
        mlb_id: 824_100 + index,
        official_date: date,
        home_team: tigers,
        away_team: opponent,
        home_score: win ? 5 : 2,
        away_score: win ? 2 : 5,
        status: "final"
      )
      TeamDailyMetric.create!(
        team: tigers,
        metric_date: date,
        source_start_date: date,
        source_end_date: date,
        sample_size: 1,
        calculation_version: "v1",
        calculated_at: calculated_at,
        source_name: "NineLens daily analytics",
        metrics: { games: 1, wins: win ? 1 : 0, losses: win ? 0 : 1, runs_scored: win ? 5 : 2, runs_allowed: win ? 2 : 5 }
      )
    end

    preview_date = Date.new(2026, 7, 19)
    create_game(
      schedule: schedule,
      mlb_id: 824_200,
      official_date: preview_date,
      home_team: opponent,
      away_team: tigers,
      home_score: 0,
      away_score: 0,
      status: "preview"
    )
    TeamDailyMetric.create!(
      team: tigers,
      metric_date: preview_date,
      source_start_date: preview_date,
      source_end_date: preview_date,
      sample_size: 1,
      calculation_version: "v1",
      calculated_at: calculated_at,
      source_name: "NineLens daily analytics",
      metrics: { games: 1, wins: 0, losses: 0, ties: 1, runs_scored: 0, runs_allowed: 0 }
    )

    get api_home_path, params: { date: preview_date.iso8601 }

    recent = json_body.dig("data", "team_pulse", "recent_form").find { |entry| entry.dig("team", "abbreviation") == "DET" }
    expect(recent).to include("recent_games" => 10, "recent_wins" => 8, "recent_losses" => 2, "recent_ties" => 0)
  end
end
