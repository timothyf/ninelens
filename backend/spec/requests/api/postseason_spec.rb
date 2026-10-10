require "rails_helper"

RSpec.describe "Api::Postseason", type: :request do
  it "returns playoff teams, results, upcoming games, and series rounds during an active postseason" do
    schedule = create_schedule(season: 2026)
    braves = create_team(name: "Atlanta Braves", abbreviation: "ATL")
    phillies = create_team(name: "Philadelphia Phillies", abbreviation: "PHI")
    hitter = create_player(team: braves, attributes: { first_name: "Ronald", last_name: "Acuna" })
    pitcher = create_player(team: braves, attributes: { first_name: "Spencer", last_name: "Strider" })
    pinch_hitter = create_player(team: braves, attributes: { first_name: "Bench", last_name: "Bat" })
    short_relief_pitcher = create_player(team: braves, attributes: { first_name: "Brief", last_name: "Relief" })
    wild_card = create_game(schedule: schedule, home_team: braves, away_team: phillies, game_type: "F", status: "final", official_date: Date.new(2026, 10, 1), home_score: 4, away_score: 2, raw_data: { "description" => "NL Wild Card 'A' Game 1", "seriesDescription" => "NL Wild Card Series", "seriesGameNumber" => 1, "ifNecessary" => "N" })
    create_game(schedule: schedule, home_team: braves, away_team: phillies, game_type: "D", status: "preview", official_date: Date.new(2026, 10, 10), raw_data: { "description" => "NLDS 'A' Game 1", "seriesDescription" => "NL Division Series", "seriesGameNumber" => 1, "ifNecessary" => "N" })
    GamePlayerBattingLine.create!(game: wild_card, player: hitter, team: braves, opponent_team: phillies, home: true, plate_appearances: 5, at_bats: 4, runs: 2, hits: 2, home_runs: 1, runs_batted_in: 3, walks: 1, source_name: "spec", last_synced_at: Time.current)
    GamePlayerBattingLine.create!(game: wild_card, player: pinch_hitter, team: braves, opponent_team: phillies, home: true, plate_appearances: 1, at_bats: 1, hits: 1, home_runs: 1, source_name: "spec", last_synced_at: Time.current)
    GamePlayerPitchingLine.create!(game: wild_card, player: pitcher, team: braves, opponent_team: phillies, home: true, starter: true, outs_recorded: 21, innings_pitched: "7.0", hits: 4, earned_runs: 1, walks: 1, strikeouts: 9, decision: "(W, 1-0)", source_name: "spec", last_synced_at: Time.current)
    GamePlayerPitchingLine.create!(game: wild_card, player: short_relief_pitcher, team: braves, opponent_team: phillies, home: true, outs_recorded: 1, innings_pitched: "0.1", strikeouts: 1, source_name: "spec", last_synced_at: Time.current)

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
    expect(json_body.dig("data", "leaders", "batting", 0)).to include(
      "player" => include("full_name" => "Ronald Acuna"), "team" => include("abbreviation" => "ATL"),
      "games" => 1, "at_bats" => 4, "hits" => 2, "home_runs" => 1, "runs_batted_in" => 3,
      "batting_average" => 0.5, "ops" => 1.85
    )
    expect(json_body.dig("data", "leaders", "pitching", 0)).to include(
      "player" => include("full_name" => "Spencer Strider"), "team" => include("abbreviation" => "ATL"),
      "games" => 1, "innings_pitched" => "7.0", "wins" => 1, "losses" => 0,
      "strikeouts" => 9, "era" => 1.286, "whip" => 0.714
    )
    expect(json_body.dig("data", "leaders", "batting").size).to eq(1)
    expect(json_body.dig("data", "leaders", "pitching").size).to eq(1)
  end

  it "marks the page inactive outside the current postseason" do
    schedule = create_schedule(season: 2025)
    create_game(schedule: schedule, game_type: "W", status: "final", official_date: Date.new(2025, 10, 30), home_score: 5, away_score: 2, raw_data: { "ifNecessary" => "N" })

    get api_postseason_path, params: { season: 2025 }

    expect(json_body.dig("data", "active")).to be(false)
    expect(json_body.dig("data", "rounds")).to eq([])
    expect(json_body.dig("data", "leaders")).to eq("batting" => [], "pitching" => [])
  end
end
