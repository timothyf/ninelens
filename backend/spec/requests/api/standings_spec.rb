require "rails_helper"

RSpec.describe "Api::Standings", type: :request do
  it "returns division standings from final regular-season games" do
    tigers = create_team(mlb_id: 116, name: "Detroit Tigers", abbreviation: "DET")
    guardians = create_team(mlb_id: 114, name: "Cleveland Guardians", abbreviation: "CLE")
    schedule = create_schedule(season: 2026, schedule_type: "R")
    [
      [ tigers, guardians, 5, 2 ],
      [ guardians, tigers, 3, 1 ],
      [ tigers, guardians, 4, 2 ]
    ].each_with_index do |(home, away, home_score, away_score), index|
      create_game(
        schedule: schedule,
        mlb_id: 825_000 + index,
        official_date: Date.new(2026, 7, 10) + index.days,
        home_team: home,
        away_team: away,
        home_score: home_score,
        away_score: away_score,
        status: "final",
        game_type: "R"
      )
    end
    create_game(
      schedule: schedule,
      mlb_id: 825_100,
      official_date: Date.new(2026, 7, 13),
      home_team: guardians,
      away_team: tigers,
      home_score: 0,
      away_score: 0,
      status: "preview",
      game_type: "R"
    )

    get api_standings_path, params: { season: 2026 }

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", "season")).to eq(2026)
    expect(json_body.dig("data", "as_of")).to eq("2026-07-12")
    expect(json_body.dig("data", "season_status")).to eq("in_progress")
    expect(json_body.dig("data", "playoff_odds")).to include(
      "simulations" => NineLensConfig.fetch(:operations, :projections, :playoff_odds_simulations),
      "remaining_games" => 1
    )
    central = json_body.dig("data", "leagues", 0, "divisions").find { |division| division.fetch("key") == "al_central" }
    expect(central.fetch("teams").map { |row| row.dig("team", "abbreviation") }).to eq(%w[DET CLE])
    expect(central.dig("teams", 0)).to include(
      "rank" => 1,
      "wins" => 2,
      "losses" => 1,
      "winning_percentage" => 0.667,
      "games_back" => 0.0,
      "run_differential" => 3
    )
    expect(central.dig("teams", 1)).to include("games_back" => 1.0)
    division_ranks = StandingsSnapshotQuery.new(season: 2026)
    expect(division_ranks.division_rank_for(tigers)).to include(rank: 1, games_ahead: 1.0)
    expect(division_ranks.division_rank_for(guardians)).to include(rank: 2, games_behind: 1.0)

    expect(central.dig("teams", 0, "playoff_odds", "playoffs")).to eq(100.0)
    wild_card = json_body.dig("data", "leagues", 0, "wild_card")
    expect(wild_card.fetch("cutoff_positions")).to eq(3)
    expect(wild_card.dig("teams", 0, "team", "abbreviation")).to eq("CLE")
    expect(wild_card.dig("teams", 0)).to include("wild_card_position" => 1, "wild_card_games_back" => 0.0)
  end

  it "rejects an invalid season" do
    get api_standings_path, params: { season: "not-a-year" }

    expect(response).to have_http_status(:unprocessable_content)
    expect(json_body.fetch("message")).to eq("Season must be a valid year")
  end
end
