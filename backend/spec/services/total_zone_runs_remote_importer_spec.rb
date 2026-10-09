require "rails_helper"

RSpec.describe TotalZoneRunsRemoteImporter, type: :service do
  it "normalizes JSON rows into the canonical TZR import format" do
    response = instance_double(Net::HTTPSuccess, body: {
      "data" => [
        {
          "year" => 1984,
          "mlb_id" => 123457,
          "first_name" => "Alex",
          "last_name" => "Mason",
          "team_id" => 116,
          "team_abbreviation" => "DET",
          "team_name" => "Detroit Tigers",
          "totalZoneRuns" => 18.4
        }
      ]
    }.to_json)
    allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:new).and_return(http)
    allow(http).to receive(:use_ssl=)
    allow(http).to receive(:open_timeout=)
    allow(http).to receive(:read_timeout=)
    allow(http).to receive(:request).and_return(response)

    result = described_class.call(url: "https://example.test/total-zone.json")

    expect(result[:success]).to be(true)
    csv = CSV.parse(result.dig(:data, :csv_data), headers: true)
    expect(csv.first.to_h).to include(
      "season" => "1984",
      "playerId" => "123457",
      "teamAbbrev" => "DET",
      "TZR" => "18.4"
    )
  end
end
