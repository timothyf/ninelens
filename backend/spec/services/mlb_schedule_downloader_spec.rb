require "rails_helper"

RSpec.describe MlbScheduleDownloader do
  it "downloads the hydrated MLB schedule payload" do
    downloader = described_class.new(
      start_date: "2026-07-14",
      end_date: "2026-07-15",
      game_types: "R,A"
    )
    payload = { "dates" => [ { "games" => [ { "gamePk" => 823_443 } ] } ] }

    allow(downloader).to receive(:fetch_json) do |url|
      query = Rack::Utils.parse_nested_query(URI(url).query)
      expect(query).to include(
        "sportId" => "1",
        "startDate" => "2026-07-14",
        "endDate" => "2026-07-15",
        "gameTypes" => "R,A",
        "hydrate" => "team,probablePitcher,venue"
      )
      payload
    end

    result = downloader.call

    expect(result[:success]).to be(true)
    expect(result.dig(:data, :payload)).to eq(payload)
    expect(result.dig(:data, :game_count)).to eq(1)
    expect(result.dig(:data, :fetched_at)).to be_present
  end

  it "allows a valid schedule response with no games" do
    downloader = described_class.new(start_date: "2026-12-01", end_date: "2026-12-01")
    allow(downloader).to receive(:fetch_json).and_return({ "dates" => [] })

    result = downloader.call

    expect(result[:success]).to be(true)
    expect(result.dig(:data, :game_count)).to eq(0)
    expect(result.dig(:data, :game_types)).to eq(%w[R W D L F])
  end

  it "returns validation failures before making a request" do
    downloader = described_class.new(start_date: "2026-07-15", end_date: "2026-07-14")
    expect(downloader).not_to receive(:fetch_json)

    result = downloader.call

    expect(result[:success]).to be(false)
    expect(result[:message]).to eq("End date must be greater than or equal to start date")
  end

  it "falls back to the alternate official schedule route after a 406 response" do
    downloader = described_class.new(start_date: "2026-10-17", end_date: "2026-10-19")
    primary_url = downloader.send(:build_url)
    alternate_url = primary_url.sub("/api/v1/schedule?", "/api/v1/schedule/games/?")

    expect(MlbStatsApiClient).to receive(:get_json).with(
      primary_url,
      user_agent: NineLensConfig.fetch(:external_services, :mlb_stats_api, :user_agents, :schedule)
    ).and_raise(MlbStatsApiClient::HttpError.new(status: 406, message: "Not Acceptable", url: primary_url))
    expect(MlbStatsApiClient).to receive(:get_json).with(
      alternate_url,
      user_agent: MlbStatsApiClient::COMPATIBLE_USER_AGENT
    ).and_return("dates" => [])

    expect(downloader.call).to include(success: true, message: "Downloaded 0 games from the MLB schedule")
  end
end
