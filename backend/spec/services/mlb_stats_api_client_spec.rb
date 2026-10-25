require "rails_helper"

RSpec.describe MlbStatsApiClient do
  let(:http) { instance_double(Net::HTTP) }

  before do
    ENV["MLB_STATS_API_RELAY_URL"] = "https://relay.example/.netlify/functions/mlb-relay"
    ENV["MLB_STATS_API_RELAY_TOKEN"] = "shared-secret"
    allow(NineLensConfig).to receive(:fetch).and_call_original
    allow(NineLensConfig).to receive(:fetch)
      .with(:external_services, :mlb_stats_api, :timeout_seconds)
      .and_return(17)
    allow(Net::HTTP).to receive(:new).and_return(http)
    allow(http).to receive(:use_ssl=)
    allow(http).to receive(:open_timeout=)
    allow(http).to receive(:read_timeout=)
  end

  after do
    ENV.delete("MLB_STATS_API_RELAY_URL")
    ENV.delete("MLB_STATS_API_RELAY_TOKEN")
  end

  it "routes through the relay and configures HTTPS, timeouts, and common JSON request headers" do
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
    expect(Net::HTTP).to have_received(:new).with("relay.example", 443)
    expect(http).to have_received(:use_ssl=).with(true)
    expect(http).to have_received(:open_timeout=).with(17)
    expect(http).to have_received(:read_timeout=).with(17)
    expect(request["User-Agent"]).to eq("NineLens Schedule")
    expect(request["Accept"]).to eq("application/json, text/plain, */*")
    expect(request["Accept-Encoding"]).to eq("identity")
    expect(request["Referer"]).to eq("https://www.mlb.com/")
    expect(request["Connection"]).to eq("close")
    expect(URI.decode_www_form(URI(request.path).query).to_h.fetch("upstream")).to eq("/api/v1/schedule?sportId=1")
  end

  it "routes MLB requests through the authenticated relay when configured" do
    ENV["MLB_STATS_API_RELAY_URL"] = "https://relay.example/.netlify/functions/mlb-relay"
    ENV["MLB_STATS_API_RELAY_TOKEN"] = "shared-secret"
    response = Net::HTTPOK.new("1.1", "200", "OK")
    allow(response).to receive(:body).and_return('{"dates":[]}')
    request = nil
    allow(http).to receive(:request) do |value|
      request = value
      response
    end

    payload = described_class.get_json(
      "https://statsapi.mlb.com/api/v1/schedule?sportId=1&gameTypes=R%2CW",
      user_agent: "NineLens Schedule"
    )

    expect(payload).to eq("dates" => [])
    expect(Net::HTTP).to have_received(:new).with("relay.example", 443)
    expect(request["X-NineLens-Relay-Token"]).to eq("shared-secret")
    relay_query = URI.decode_www_form(URI(request.path).query).to_h
    expect(relay_query.fetch("upstream")).to eq("/api/v1/schedule?sportId=1&gameTypes=R%2CW")
  end

  it "requires a relay token and an HTTPS relay URL" do
    ENV["MLB_STATS_API_RELAY_URL"] = "https://relay.example/.netlify/functions/mlb-relay"
    ENV.delete("MLB_STATS_API_RELAY_TOKEN")
    expect do
      described_class.get_json("https://statsapi.mlb.com/api/v1/schedule", user_agent: "NineLens")
    end.to raise_error(RuntimeError, "MLB_STATS_API_RELAY_TOKEN is required when MLB_STATS_API_RELAY_URL is set")

    ENV["MLB_STATS_API_RELAY_TOKEN"] = "shared-secret"
    ENV["MLB_STATS_API_RELAY_URL"] = "http://relay.example/mlb-relay"
    expect do
      described_class.get_json("https://statsapi.mlb.com/api/v1/schedule", user_agent: "NineLens")
    end.to raise_error(RuntimeError, "MLB_STATS_API_RELAY_URL must use HTTPS")
  end

  it "refuses to make a direct MLB request when the relay is not configured" do
    ENV.delete("MLB_STATS_API_RELAY_URL")

    expect do
      described_class.get_json("https://statsapi.mlb.com/api/v1/schedule", user_agent: "NineLens")
    end.to raise_error(RuntimeError, "MLB_STATS_API_RELAY_URL is required")
    expect(Net::HTTP).not_to have_received(:new)
  end

  it "raises a descriptive error for unsuccessful responses" do
    response = Net::HTTPNotFound.new("1.1", "404", "Not Found")
    allow(http).to receive(:request).and_return(response)

    expect do
      described_class.get_json("https://statsapi.mlb.com/missing", user_agent: "NineLens")
    end.to raise_error(MlbStatsApiClient::HttpError, "HTTP 404: Not Found (https://statsapi.mlb.com/missing)") do |error|
      expect(error.status).to eq(404)
      expect(error.url).to eq("https://statsapi.mlb.com/missing")
    end
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
