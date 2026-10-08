require "rails_helper"

RSpec.describe "Api::Postseason", type: :request do
  it "returns playoff teams, results, upcoming games, and series rounds during an active postseason" do
    schedule = create_schedule(season: 2026)
    braves = create_team(name: "Atlanta Braves", abbreviation: "ATL")
    phillies = create_team(name: "Philadelphia Phillies", abbreviation: "PHI")
    create_game(schedule: schedule, home_team: braves, away_team: phillies, game_type: "F", status: "final", official_date: Date.new(2026, 10, 1), home_score: 4, away_score: 2, raw_data: { "description" => "NL Wild Card 'A' Game 1", "seriesDescription" => "NL Wild Card Series", "seriesGameNumber" => 1, "ifNecessary" => "N" })
    create_game(schedule: schedule, home_team: braves, away_team: phillies, game_type: "D", status: "preview", official_date: Date.new(2026, 10, 10), raw_data: { "description" => "NLDS 'A' Game 1", "seriesDescription" => "NL Division Series", "seriesGameNumber" => 1, "ifNecessary" => "N" })

    get api_postseason_path, params: { season: 2026 }

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", "active")).to be(true)
    expect(json_body.dig("data", "playoff_teams").size).to eq(2)
    expect(json_body.dig("data", "game_results").size).to eq(1)
    expect(json_body.dig("data", "upcoming_games").size).to eq(1)
    expect(json_body.dig("data", "game_results", 0, "away_team", "abbreviation")).to eq("PHI")
    expect(json_body.dig("data", "game_results", 0, "home_team", "abbreviation")).to eq("ATL")
    expect(json_body.dig("data", "upcoming_games", 0, "away_team", "abbreviation")).to eq("PHI")
    expect(json_body.dig("data", "upcoming_games", 0, "home_team", "abbreviation")).to eq("ATL")
    expect(json_body.dig("data", "rounds", 0, "series", 0, "name")).to eq("NL Wild Card 'A'")
  end

  it "marks the page inactive outside the current postseason" do
    schedule = create_schedule(season: 2025)
    create_game(schedule: schedule, game_type: "W", status: "final", official_date: Date.new(2025, 10, 30), home_score: 5, away_score: 2, raw_data: { "ifNecessary" => "N" })

    get api_postseason_path, params: { season: 2025 }

    expect(json_body.dig("data", "active")).to be(false)
    expect(json_body.dig("data", "rounds")).to eq([])
  end
end
