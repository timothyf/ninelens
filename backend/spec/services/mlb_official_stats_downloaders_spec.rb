require "rails_helper"

RSpec.describe "MLB official stats downloaders", type: :service do
  it "downloads standings through the shared relay client" do
    allow(MlbStatsApiClient).to receive(:get_json).and_return(
      "records" => [{ "teamRecords" => [{ "team" => { "id" => 116 }, "wins" => 90, "losses" => 72 }] }]
    )

    expect(MlbStandingsDownloader.call(season: 2026)).to eq(116 => { "wins" => 90, "losses" => 72 })
    expect(MlbStatsApiClient).to have_received(:get_json).with(
      a_string_including("/api/v1/standings", "season=2026"),
      user_agent: a_string_including("NineLens")
    )
  end

  it "downloads player season totals through the shared relay client" do
    allow(MlbStatsApiClient).to receive(:get_json).and_return(
      "stats" => [{ "splits" => [{ "stat" => { "hits" => 182 } }] }]
    )

    expect(MlbPlayerSeasonTotalsDownloader.call(mlb_id: 682_985, season: 2026, category: "batting")).to eq("hits" => 182)
    expect(MlbStatsApiClient).to have_received(:get_json).with(
      a_string_including("/api/v1/people/682985/stats", "season=2026", "group=hitting"),
      user_agent: a_string_including("NineLens")
    )
  end
end
