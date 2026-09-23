require "rails_helper"
require "csv"
require "json"

RSpec.describe MlbPlayerContractsDownloader, type: :service do
  it "normalizes FanGraphs payroll tables into import-ready CSV" do
    html = <<~HTML
      <table>
        <thead><tr><th>Player</th><th>Contract</th><th>AAV</th><th>2026</th><th>2027</th></tr></thead>
        <tbody><tr><td><a href="/players/12345/foo">Test Player</a></td><td>2 yr, $20M (2026-27)</td><td>$10,000,000</td><td>$9,000,000</td><td>$11,000,000</td></tr></tbody>
      </table>
    HTML
    downloader = described_class.new(season: 2026, teams: ["tigers"])
    allow(downloader).to receive(:fetch_html).and_return(html)

    result = downloader.call

    expect(result[:success]).to be(true)
    expect(result.dig(:data, :row_count)).to eq(1)
    row = CSV.parse(result.dig(:data, :csv_data), headers: true).first
    expect(row["player_name"]).to eq("Test Player")
    expect(row["contract"]).to eq("2 yr, $20M (2026-27)")
    expect(JSON.parse(row["salary_by_year"])).to include("2026" => "$9,000,000")
  end

  it "rejects unknown team slugs before making requests" do
    downloader = described_class.new(season: 2026, teams: ["not-a-team"])

    expect(downloader.call).to include(success: false, message: "Unknown team slug(s): not-a-team")
  end
end
