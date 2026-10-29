require "rails_helper"

RSpec.describe FangraphsApiClient do
  let(:http) { instance_double(Net::HTTP) }

  before do
    ENV["MLB_STATS_API_RELAY_URL"] = "https://relay.example/.netlify/functions/mlb-relay"
    ENV["MLB_STATS_API_RELAY_TOKEN"] = "shared-secret"
    allow(Net::HTTP).to receive(:new).and_return(http)
    allow(http).to receive(:use_ssl=)
    allow(http).to receive(:open_timeout=)
    allow(http).to receive(:read_timeout=)
  end

  after do
    ENV.delete("MLB_STATS_API_RELAY_URL")
    ENV.delete("MLB_STATS_API_RELAY_TOKEN")
    ENV.delete("FANGRAPHS_API_RELAY_URL")
    ENV.delete("FANGRAPHS_API_RELAY_TOKEN")
  end

  it "uses the sibling FanGraphs relay and preserves the upstream query" do
    response = Net::HTTPOK.new("1.1", "200", "OK")
    allow(response).to receive(:body).and_return('{"data":[]}')
    request = nil
    allow(http).to receive(:request) { |value| request = value; response }

    payload = described_class.get_json("https://www.fangraphs.com/api/leaders/major-league/data?stats=bat&season=2026", timeout_seconds: 17, user_agent: "NineLens")

    expect(payload).to eq("data" => [])
    expect(Net::HTTP).to have_received(:new).with("relay.example", 443)
    expect(http).to have_received(:open_timeout=).with(17)
    expect(request["X-NineLens-Relay-Token"]).to eq("shared-secret")
    expect(URI.decode_www_form(URI(request.path).query).to_h.fetch("upstream")).to eq("/api/leaders/major-league/data?stats=bat&season=2026")
  end

  it "supports an explicit HTTPS relay URL and token" do
    ENV["FANGRAPHS_API_RELAY_URL"] = "https://custom.example/fangraphs-relay"
    ENV["FANGRAPHS_API_RELAY_TOKEN"] = "custom-secret"
    response = Net::HTTPOK.new("1.1", "200", "OK")
    allow(response).to receive(:body).and_return('{"data":[]}')
    request = nil
    allow(http).to receive(:request) { |value| request = value; response }

    described_class.get_json("https://www.fangraphs.com/api/leaders/major-league/data", timeout_seconds: 17, user_agent: "NineLens")
    expect(Net::HTTP).to have_received(:new).with("custom.example", 443)
    expect(request["X-NineLens-Relay-Token"]).to eq("custom-secret")
  end

  it "rejects an insecure relay URL" do
    ENV["FANGRAPHS_API_RELAY_URL"] = "http://relay.example/fangraphs-relay"
    expect do
      described_class.get_json("https://www.fangraphs.com/api/leaders/major-league/data", timeout_seconds: 17, user_agent: "NineLens")
    end.to raise_error(RuntimeError, "FanGraphs API relay URL must use HTTPS")
    expect(Net::HTTP).not_to have_received(:new)
  end
end
