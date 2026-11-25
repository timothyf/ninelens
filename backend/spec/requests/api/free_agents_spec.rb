require "rails_helper"

RSpec.describe "Free agents API", type: :request do
  it "returns separate batter and pitcher tables for the current offseason" do
    query = instance_double(FreeAgentsQuery, result: {
      season: 2026, as_of: Date.new(2026, 11, 21),
      batters: [ { player_id: 1, player_name: "Batter" } ],
      pitchers: [ { player_id: 2, player_name: "Pitcher" } ]
    })
    allow(FreeAgentsQuery).to receive(:new).with(on: ApplicationCalendar.current_date).and_return(query)

    get "/api/free_agents"

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("data", "batters", 0, "player_name")).to eq("Batter")
    expect(response.parsed_body.dig("data", "pitchers", 0, "player_name")).to eq("Pitcher")
  end
end
