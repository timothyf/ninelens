require "rails_helper"

RSpec.describe GamesIndexQuery, type: :model do
  it "filters by team, date range, season, status, and game type" do
    tigers = create_team(mlb_id: 116, abbreviation: "DET")
    guardians = create_team(mlb_id: 114, abbreviation: "CLE")
    schedule = create_schedule(season: 2026)
    matching_game = create_game(
      schedule: schedule,
      home_team: tigers,
      away_team: guardians,
      official_date: Date.new(2026, 7, 14),
      status: "preview",
      game_type: "R"
    )
    create_game(
      schedule: schedule,
      official_date: Date.new(2026, 7, 14),
      status: "final",
      game_type: "R"
    )

    query = described_class.new(
      params: {
        team_id: tigers.id,
        start_date: "2026-07-13",
        end_date: "2026-07-15",
        season: "2026",
        status: "PREVIEW",
        game_type: "r"
      }
    )

    expect(query.results).to eq([ matching_game ])
    expect(query.metadata[:filters]).to eq(
      team_id: tigers.id,
      start_date: Date.new(2026, 7, 13),
      end_date: Date.new(2026, 7, 15),
      season: 2026,
      status: "preview",
      game_type: "R"
    )
  end

  it "normalizes reversed dates and pagination limits" do
    game = create_game(official_date: Date.new(2026, 7, 14))

    query = described_class.new(
      params: { start_date: "2026-07-15", end_date: "2026-07-13", page: 0, per_page: 500 }
    )

    expect(query.results).to eq([ game ])
    expect(query.metadata).to include(page: 1, per_page: 100)
    expect(query.metadata[:filters]).to include(
      start_date: Date.new(2026, 7, 13),
      end_date: Date.new(2026, 7, 15)
    )
  end

  it "prefers top-level filters over nested filters" do
    tigers = create_team(mlb_id: 116, abbreviation: "DET")
    guardians = create_team(mlb_id: 114, abbreviation: "CLE")
    game = create_game(home_team: tigers, away_team: guardians)
    create_game

    query = described_class.new(
      params: { team_id: tigers.id, filter: { team_id: guardians.id } }
    )

    expect(query.results).to eq([ game ])
    expect(query.metadata[:filters]).to include(team_id: tigers.id)
  end

  it "returns an if-necessary postseason game while its series is active" do
    home_team = create_team
    away_team = create_team
    schedule = create_schedule(season: 2026)
    [ [ 5, 2 ], [ 1, 3 ], [ 4, 2 ] ].each_with_index do |(home_score, away_score), index|
      create_game(
        schedule: schedule,
        home_team: home_team,
        away_team: away_team,
        official_date: Date.new(2026, 10, 12) + index.days,
        game_type: "L",
        status: "final",
        home_score: home_score,
        away_score: away_score
      )
    end
    if_necessary_game = create_game(
      schedule: schedule,
      home_team: away_team,
      away_team: home_team,
      official_date: Date.new(2026, 10, 19),
      game_type: "L",
      status: "preview",
      raw_data: { "ifNecessary" => "Y", "seriesGameNumber" => 6, "ifNecessaryDescription" => "If Necessary Game" }
    )

    query = described_class.new(params: { start_date: "2026-10-19", end_date: "2026-10-19" })

    expect(query.results).to eq([ if_necessary_game ])
  end

  it "does not return an unused if-necessary game after the series is clinched" do
    home_team = create_team
    away_team = create_team
    schedule = create_schedule(season: 2026)
    4.times do |index|
      create_game(
        schedule: schedule,
        home_team: home_team,
        away_team: away_team,
        official_date: Date.new(2026, 10, 10) + index.days,
        game_type: "L",
        status: "final",
        home_score: 5,
        away_score: 2
      )
    end
    create_game(
      schedule: schedule,
      home_team: away_team,
      away_team: home_team,
      official_date: Date.new(2026, 10, 15),
      game_type: "L",
      status: "preview",
      raw_data: { "ifNecessary" => "Y", "seriesGameNumber" => 6 }
    )

    query = described_class.new(params: { start_date: "2026-10-15", end_date: "2026-10-15" })

    expect(query.results).to be_empty
  end
end
