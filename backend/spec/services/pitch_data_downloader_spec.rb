require "rails_helper"
require "csv"

RSpec.describe PitchDataDownloader, type: :service do
  it "downloads Baseball Savant pitch rows and returns import-ready csv data" do
    downloader = described_class.new(
      start_date: "2026-04-01",
      end_date: "2026-04-01",
      game_types: "R",
      chunk_days: 7
    )

    allow(downloader).to receive(:fetch_csv).and_return(<<~CSV)
      game_date,game_pk,game_type,at_bat_number,pitch_number,pitcher,player_name,batter,pitch_type,description
      2026-04-01,777,R,1,1,9001,Pitcher One,8001,FF,called_strike
    CSV

    result = downloader.call
    csv = CSV.parse(result.dig(:data, :csv_data), headers: true)

    expect(result[:success]).to be(true)
    expect(result.dig(:data, :row_count)).to eq(1)
    expect(result.dig(:data, :start_date)).to eq("2026-04-01")
    expect(result.dig(:data, :game_types)).to eq(["R"])
    expect(csv.headers).to include("source_start_date", "source_end_date", "fetched_at_utc", "game_pk")
    expect(csv.first["source_start_date"]).to eq("2026-04-01")
    expect(csv.first["game_pk"]).to eq("777")
  end

  it "validates date range and game types before downloading" do
    bad_range = described_class.call(start_date: "2026-04-02", end_date: "2026-04-01", game_types: "R")
    bad_game_type = described_class.call(start_date: "2026-04-01", end_date: "2026-04-01", game_types: "X")

    expect(bad_range[:success]).to be(false)
    expect(bad_range[:message]).to eq("End date must be greater than or equal to start date")
    expect(bad_game_type[:success]).to be(false)
    expect(bad_game_type[:message]).to eq("Unsupported game type(s): X")
  end

  it "includes postseason game types by default" do
    downloader = described_class.new(start_date: "2026-10-01", end_date: "2026-10-01")
    allow(downloader).to receive(:fetch_csv).and_return("game_date,game_pk,game_type\n2026-10-01,900001,F\n")

    result = downloader.call

    expect(result[:success]).to be(true)
    expect(result.dig(:data, :game_types)).to eq(%w[R W D L F])
  end

  it "normalizes binary-encoded Baseball Savant csv before parsing" do
    downloader = described_class.new(
      start_date: "2026-04-01",
      end_date: "2026-04-01",
      game_types: "R",
      chunk_days: 7
    )
    csv_data = "\uFEFFgame_date,game_pk,at_bat_number,pitch_number,description\n2026-04-01,777,1,1,called_strike\n"
      .dup
      .force_encoding(Encoding::ASCII_8BIT)

    rows = downloader.send(:parse_chunk, csv_data, Date.new(2026, 4, 1), Date.new(2026, 4, 1))

    expect(rows.length).to eq(1)
    expect(rows.first["game_pk"]).to eq("777")
    expect(rows.first["source_start_date"]).to eq("2026-04-01")
  end

  it "includes both boundary dates in the Baseball Savant query" do
    downloader = described_class.new(
      start_date: "2026-04-01",
      end_date: "2026-04-01",
      game_types: "R",
      chunk_days: 1
    )
    allow(downloader).to receive(:fetch_csv) do |url|
      query = URI.parse(url).query
      expect(query).to include("game_date_gt=2026-03-31", "game_date_lt=2026-04-02")
      "game_pk,at_bat_number,pitch_number\n777,1,1\n"
    end

    expect(downloader.call[:success]).to be(true)
  end
end
