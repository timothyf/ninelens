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

  it "does not return unplayed if-necessary postseason placeholders" do
    visible_game = create_game(official_date: Date.new(2026, 10, 1), status: "preview")
    create_game(
      official_date: Date.new(2026, 10, 1),
      game_type: "F",
      status: "preview",
      raw_data: { "ifNecessary" => "Y", "ifNecessaryDescription" => "If Necessary Game" }
    )

    query = described_class.new(params: { start_date: "2026-10-01", end_date: "2026-10-01" })

    expect(query.results).to eq([ visible_game ])
  end
end
