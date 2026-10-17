require "rails_helper"

RSpec.describe MlbStatsApiClient do
  let(:http) { instance_double(Net::HTTP) }

  before do
    allow(NineLensConfig).to receive(:fetch).and_call_original
    allow(NineLensConfig).to receive(:fetch)
      .with(:external_services, :mlb_stats_api, :timeout_seconds)
      .and_return(17)
    allow(Net::HTTP).to receive(:new).and_return(http)
    allow(http).to receive(:use_ssl=)
    allow(http).to receive(:open_timeout=)
    allow(http).to receive(:read_timeout=)
  end

  it "configures HTTPS, timeouts, and common JSON request headers" do
    response = Net::HTTPOK.new("1.1", "200", "OK")
    allow(response).to receive(:body).and_return('{"dates":[]}')
    request = nil
    allow(http).to receive(:request) do |value|
      request = value
      response
    end

    payload = described_class.get_json(
      "https://statsapi.mlb.com/api/v1/schedule?sportId=1",
      user_agent: "NineLens Schedule"
    )

    expect(payload).to eq("dates" => [])
    expect(Net::HTTP).to have_received(:new).with("statsapi.mlb.com", 443)
    expect(http).to have_received(:use_ssl=).with(true)
    expect(http).to have_received(:open_timeout=).with(17)
    expect(http).to have_received(:read_timeout=).with(17)
    expect(request["User-Agent"]).to eq("NineLens Schedule")
    expect(request["Accept"]).to eq("application/json")
    expect(request.path).to eq("/api/v1/schedule?sportId=1")
  end

  it "derives non-SSL requests from the URL scheme" do
    response = Net::HTTPOK.new("1.1", "200", "OK")
    allow(response).to receive(:body).and_return("{}")
    allow(http).to receive(:request).and_return(response)

    described_class.get_json("http://example.test/api/v1/teams", user_agent: "NineLens")

    expect(Net::HTTP).to have_received(:new).with("example.test", 80)
    expect(http).to have_received(:use_ssl=).with(false)
  end

  it "raises a descriptive error for unsuccessful responses" do
    response = Net::HTTPNotFound.new("1.1", "404", "Not Found")
    allow(http).to receive(:request).and_return(response)

    expect do
      described_class.get_json("https://statsapi.mlb.com/missing", user_agent: "NineLens")
    end.to raise_error(RuntimeError, "HTTP 404: Not Found")
  end

  it "retries an MLB 406 response with browser-compatible request headers" do
    rejected = Net::HTTPNotAcceptable.new("1.1", "406", "Not Acceptable")
    accepted = Net::HTTPOK.new("1.1", "200", "OK")
    allow(accepted).to receive(:body).and_return('{"dates":[]}')
    requests = []
    allow(http).to receive(:request) do |request|
      requests << request
      requests.length == 1 ? rejected : accepted
    end

    payload = described_class.get_json(
      "https://statsapi.mlb.com/api/v1/schedule?sportId=1",
      user_agent: "NineLens/1.0 (MLB schedule synchronization)"
    )

    expect(payload).to eq("dates" => [])
    expect(requests.length).to eq(2)
    expect(requests.first["User-Agent"]).to eq("NineLens/1.0 (MLB schedule synchronization)")
    expect(requests.second["User-Agent"]).to eq(MlbStatsApiClient::COMPATIBLE_USER_AGENT)
    expect(requests.second["Accept-Language"]).to eq("en-US,en;q=0.9")
    expect(requests.second["Cache-Control"]).to eq("no-cache")
  end

  it "allows JSON parser errors to retain their error type" do
    response = Net::HTTPOK.new("1.1", "200", "OK")
    allow(response).to receive(:body).and_return("not-json")
    allow(http).to receive(:request).and_return(response)

    expect do
      described_class.get_json("https://statsapi.mlb.com/bad-json", user_agent: "NineLens")
    end.to raise_error(JSON::ParserError)
  end

  it "is used by the MLB JSON downloaders with their configured user agents" do
    service_config = NineLensConfig.fetch(:external_services, :mlb_stats_api)
    url = "https://statsapi.mlb.com/api/v1/example"
    payload = { "ok" => true }
    downloaders = {
      MlbGameDetailsDownloader.new(mlb_id: 1) => :game_details,
      MlbRosterDownloader.new(team_mlb_id: 1) => :roster,
      MlbScheduleDownloader.new(start_date: Date.current, end_date: Date.current) => :schedule,
      MlbPlayerProfilesDownloader.new(mlb_ids: [ 1 ]) => :player_profiles,
      MlbPlayerTransactionsDownloader.new(player_mlb_id: 1) => :transactions,
      MlbTradeDetailsDownloader.new(mlb_transaction_id: 1) => :transactions
    }

    downloaders.each do |downloader, user_agent_key|
      expect(described_class).to receive(:get_json).with(
        url,
        user_agent: service_config.fetch(:user_agents).fetch(user_agent_key)
      ).and_return(payload)
      expect(downloader.send(:fetch_json, url)).to eq(payload)
    end
  end
end
