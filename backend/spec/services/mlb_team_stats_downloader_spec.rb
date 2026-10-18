require "rails_helper"

RSpec.describe MlbTeamStatsDownloader, type: :service do
  it "parses official MLB team hitting totals without aggregating player rows" do
    response = instance_double(
      Net::HTTPSuccess,
      body: {
        "stats" => [{
          "splits" => [{
            "team" => { "id" => 116 },
            "stat" => {
              "gamesPlayed" => 130,
              "hits" => 1060,
              "homeRuns" => 154,
              "avg" => ".242",
              "ops" => ".723"
            }
          }]
        }]
      }.to_json
    )
    allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
    allow(MlbStatsApiClient).to receive(:get_json).and_return(JSON.parse(response.body))

    expect(described_class.call(season: 2026, category: "batting")).to eq(
      116 => {
        "gamesPlayed" => 130,
        "hits" => 1060,
        "homeRuns" => 154,
        "avg" => ".242",
        "ops" => ".723"
      }
    )
    expect(MlbStatsApiClient).to have_received(:get_json).with(
      a_string_including("/api/v1/teams/stats", "sportIds=1"),
      user_agent: a_string_including("NineLens")
    )
  end
end
