require "rails_helper"

RSpec.describe "Season awards API", type: :request do
  let(:season) { ApplicationCalendar.current_date.year - 1 }

  it "groups cached MLB winners by award and league" do
    Schedule.create!(
      season: season,
      schedule_type: "regular",
      start_date: Date.new(season, 3, 1),
      end_date: Date.new(season, 11, 1),
      source_name: "spec",
      source_key: "awards-#{season}",
      last_synced_at: Time.current
    )
    SeasonAward.create!(
      season: season,
      award_id: "ALMVP",
      award_name: "AL MVP",
      player_mlb_id: 12345,
      player_name: "Test Winner",
      team_mlb_id: 116,
      source_url: "https://statsapi.mlb.com/api/v1/awards/ALMVP/recipients?season=#{season}"
    )
    allow(MlbSeasonAwardsSync).to receive(:call).with(season: season).and_return(success: true)

    get "/api/season_review/awards", params: { season: season }

    expect(response).to have_http_status(:ok)
    data = response.parsed_body.fetch("data")
    expect(data.fetch("status")).to eq("ready")
    expect(data.fetch("groups").map { |group| group.fetch("name") }).to eq(["MVP", "Cy Young", "Gold Glove"])
    expect(data.dig("groups", 0, "leagues", 0, "recipients", 0, "player_name")).to eq("Test Winner")
  end
end
