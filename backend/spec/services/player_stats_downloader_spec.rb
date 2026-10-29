require "rails_helper"
require "csv"

RSpec.describe PlayerStatsDownloader, type: :service do
  it "uses the FanGraphs API client for batting and fielding leaderboards" do
    downloader = described_class.new(category: "batting", start_year: 2026, end_year: 2026)
    requests = []
    allow(FangraphsApiClient).to receive(:get_json) do |url, **options|
      requests << [ URI(url), options ]
      { "data" => [] }
    end

    expect(downloader.send(:fetch_fangraphs_values, 2026)).to eq({})
    expect(downloader.send(:fetch_fangraphs_fielding_values, 2026)).to eq({})
    expect(requests.map { |uri, _| URI.decode_www_form(uri.query).to_h.fetch("stats") }).to eq(%w[bat fld])
    expect(requests.map { |uri, _| uri.path }).to eq([ "/api/leaders/major-league/data" ] * 2)
  end

  it "does not require the batting WAR setting for pitching imports" do
    downloader = described_class.new(category: "pitching", start_year: 2026, end_year: 2026)

    allow(NineLensConfig).to receive(:fetch).and_call_original
    allow(NineLensConfig).to receive(:fetch).with(
      :external_services, :baseball_reference, :batting_war_url
    ).and_raise(KeyError, "key not found: :batting_war_url")

    expect { downloader.send(:service_config) }.not_to raise_error
  end

  it "uses the default batting WAR URL when an older config is loaded" do
    downloader = described_class.new(category: "batting", start_year: 2026, end_year: 2026)

    allow(NineLensConfig).to receive(:fetch).and_call_original
    allow(NineLensConfig).to receive(:fetch).with(
      :external_services, :baseball_reference
    ).and_return({ war_url: "https://example.test/pitching-war.csv" })

    expect(downloader.send(:service_config).fetch(:baseball_reference_batting_url)).to eq(
      PlayerStatsDownloader::DEFAULT_BASEBALL_REFERENCE_BATTING_WAR_URL
    )
  end

  it "downloads MLB batting rows and returns import-ready csv data" do
    downloader = described_class.new(category: "batting", start_year: 2026, end_year: 2026)
    allow(downloader).to receive(:fetch_fangraphs_values).and_return(
      408234 => {
        "wOBA" => 0.398, "wRC+" => 148.4, "OPS+" => 146.2,
        "Offense" => 31.5, "BaseRunning" => 1.4, "Defense" => -2.3,
        "GB%" => 0.39, "FB%" => 0.41, "LD%" => 0.2,
        "Pull%" => 0.43, "Cent%" => 0.32, "Oppo%" => 0.25, "ballsInPlay" => 410,
        "Swing%" => 0.49, "O-Swing%" => 0.27, "Contact%" => 0.78,
        "Z-Contact%" => 0.85, "SwStr%" => 0.11
      }
    )
    allow(downloader).to receive(:fetch_baseball_reference_batting_values).and_return(
      2026 => { 408234 => { "WAR" => 4.2 } }
    )
    allow(downloader).to receive(:fetch_statcast_batting_values).and_return({})
    allow(downloader).to receive(:fetch_fangraphs_fielding_values).and_return(
      408234 => { "DRS" => -4.0 }
    )
    allow(downloader).to receive(:fetch_json).and_return(
      {
        "stats" => [
          {
            "playerId" => 408234,
            "playerName" => "Miguel Cabrera",
            "firstName" => "Miguel",
            "lastName" => "Cabrera",
            "teamId" => 116,
            "teamAbbrev" => "DET",
            "teamName" => "Detroit Tigers",
            "teamShortName" => "Tigers",
            "gamesPlayed" => 140,
            "homeRuns" => 31,
            "ops" => ".920"
          }
        ]
      }
    )

    result = downloader.call
    csv = CSV.parse(result.dig(:data, :csv_data), headers: true)

    expect(result[:success]).to be(true)
    expect(result.dig(:data, :row_count)).to eq(1)
    expect(csv.headers).to include("source_season", "stat_type", "playerFirstName", "playerLastName", "teamName")
    expect(csv.first["stat_type"]).to eq("batter")
    expect(csv.first["season"]).to eq("2026")
    expect(csv.first["playerFirstName"]).to eq("Miguel")
    expect(csv.first.to_h).to include(
      "WAR" => "4.2",
      "wOBA" => "0.398",
      "wRC+" => "148.4",
      "OPS+" => "146.2",
      "Offense" => "31.5",
      "BaseRunning" => "1.4",
      "Defense" => "-2.3",
      "GB%" => "0.39",
      "DRS" => "-4.0",
      "Oppo%" => "0.25",
      "Swing%" => "0.49",
      "O-Swing%" => "0.27",
      "Contact%" => "0.78",
      "Z-Contact%" => "0.85",
      "SwStr%" => "0.11"
    )
  end

  it "derives OPS+ from the FanGraphs league-adjusted OBP+ and SLG+ components" do
    downloader = described_class.new(category: "batting", start_year: 2025, end_year: 2025)

    expect(downloader.send(:calculated_ops_plus, { "OBP+" => 99.9645, "SLG+" => 121.64 })).to be_within(0.0001).of(121.6045)
    expect(downloader.send(:calculated_ops_plus, { "OBP+" => nil, "SLG+" => 121.64 })).to be_nil
  end

  it "adds FanGraphs pitcher rate and outcome values to MLB pitching rows" do
    downloader = described_class.new(category: "pitching", start_year: 2026, end_year: 2026)
    allow(downloader).to receive(:fetch_fangraphs_values).and_return(
      669373 => {
        "WAR" => 6.6, "K%" => 0.322, "BB%" => 0.044, "K-BB%" => 0.278, "K/BB" => 7.3,
        "BABIP" => 0.273, "LOB%" => 0.806, "ERA-" => 54, "FIP" => 2.45,
        "FIP-" => 58, "xFIP" => 2.66, "xFIP-" => 63, "SIERA" => 2.71, "xERA" => 2.70,
        "RA9-Wins" => 7.1, "WPA" => 4.0, "WPA/LI" => 5.2, "RE24" => 43.6,
        "Clutch" => -1.0, "RAR" => 59.1, "pLI" => 0.95, "SD" => 2, "MD" => 1
      }
    )
    pitcher_fielding = [
      {
        team_abbreviation: "2 TMS", position: "P", games: 19, innings: 113.2,
        putouts: 1, assists: 9, fielding_errors: 0, fielding_percentage: 1.0,
        defensive_runs_saved: -1.0, outs_above_average: nil
      }
    ]
    allow(downloader).to receive(:fetch_fangraphs_fielding_values).and_return(
      669373 => { "DRS" => -1.0, "fieldingByPosition" => pitcher_fielding.to_json }
    )
    allow(downloader).to receive(:fetch_statcast_values).and_return(
      669373 => { "wOBAAllowed" => 0.246, "xwOBAAllowed" => 0.266 }
    )
    allow(downloader).to receive(:fetch_statcast_run_values).and_return(
      669373 => { "PitchingRuns" => 51.4 }
    )
    allow(downloader).to receive(:fetch_baseball_reference_values).and_return(
      2026 => { 669373 => { "RAA" => 19.3 } }
    )
    allow(downloader).to receive(:fetch_json).and_return(
      {
        "stats" => [
          {
            "playerId" => 669373, "firstName" => "Tarik", "lastName" => "Skubal",
            "teamId" => 116, "teamAbbrev" => "DET", "teamName" => "Detroit Tigers",
            "teamShortName" => "Tigers", "inningsPitched" => "190.1", "earnedRunAverage" => "2.21"
          }
        ]
      }
    )

    result = downloader.call
    row = CSV.parse(result.dig(:data, :csv_data), headers: true).first.to_h

    expect(row).to include(
      "K%" => "0.322", "BB%" => "0.044", "K-BB%" => "0.278", "K/BB" => "7.3",
      "BABIP" => "0.273", "LOB%" => "0.806", "ERA-" => "54", "FIP" => "2.45",
      "FIP-" => "58", "xFIP" => "2.66", "xFIP-" => "63", "SIERA" => "2.71",
      "xERA" => "2.7", "wOBAAllowed" => "0.246", "xwOBAAllowed" => "0.266",
      "RA9-Wins" => "7.1", "WPA" => "4.0", "WPA/LI" => "5.2", "RE24" => "43.6",
      "Clutch" => "-1.0", "RAR" => "59.1", "RAA" => "19.3", "PitchingRuns" => "51.4",
      "pLI" => "0.95", "SD" => "2", "MD" => "1"
    )
    expect(JSON.parse(row.fetch("fieldingByPosition"))).to contain_exactly(
      hash_including("position" => "P", "games" => 19, "fielding_percentage" => 1.0)
    )
  end

  it "parses Statcast pitcher wOBA allowed values" do
    downloader = described_class.new(category: "pitching", start_year: 2025, end_year: 2025)
    csv_body = "\uFEFF" + <<~CSV
      "last_name, first_name","player_id","year","player_id","player_name","k_percent","bb_percent","babip","xera","woba","xwoba"
      "Skubal, Tarik",669373,2025,669373,"Skubal, Tarik",32.2,4.4,".273",2.70,".246",".266"
    CSV
    response = instance_double(Net::HTTPSuccess, body: csv_body.b)
    allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
    allow_any_instance_of(Net::HTTP).to receive(:request).and_return(response)

    expect(downloader.send(:fetch_statcast_values, 2025)).to eq(
      669373 => {
        "K%" => 0.322, "BB%" => 0.044, "BABIP" => 0.273, "xERA" => 2.7,
        "wOBAAllowed" => 0.246, "xwOBAAllowed" => 0.266
      }
    )
  end

  it "parses Statcast batting quality and discipline fallback values" do
    downloader = described_class.new(category: "batting", start_year: 2026, end_year: 2026)
    csv_body = <<~CSV
      player_id,woba,groundballs_percent,flyballs_percent,linedrives_percent,pull_percent,straightaway_percent,opposite_percent,swing_percent,oz_swing_percent,iz_contact_percent,whiff_percent,batted_ball
      682985,.390,42.0,31.0,22.0,44.0,34.0,22.0,48.0,27.0,85.0,22.0,410
    CSV
    response = instance_double(Net::HTTPSuccess, body: csv_body)
    allow(downloader).to receive(:request_csv).and_return(response)

    expect(downloader.send(:fetch_statcast_batting_values, 2026)).to eq(
      682985 => {
        "wOBA" => 0.39, "GB%" => 0.42, "FB%" => 0.31, "LD%" => 0.22,
        "Pull%" => 0.44, "Cent%" => 0.34, "Oppo%" => 0.22, "Swing%" => 0.48,
        "O-Swing%" => 0.27, "Contact%" => 0.78, "Z-Contact%" => 0.85,
        "SwStr%" => 0.1056, "ballsInPlay" => 410
      }
    )
  end

  it "parses and combines Baseball-Reference batting WAR values by player and season" do
    downloader = described_class.new(category: "batting", start_year: 2026, end_year: 2026)
    csv_body = <<~CSV
      name_common,mlb_ID,year_ID,team_ID,PA,WAR,runs_above_avg_off,runs_br,runs_above_avg_def,OPS_plus
      Alex Mason,123456,2026,DET,300,2.1,15.0,1.2,-2.0,130
      Alex Mason,123456,2026,LAD,100,1.4,8.0,0.4,1.0,150
      Old Season,654321,2025,DET,500,5.0,30.0,2.0,4.0,160
    CSV
    response = instance_double(Net::HTTPSuccess, body: csv_body)
    allow(downloader).to receive(:request_csv).and_return(response)

    expect(downloader.send(:fetch_baseball_reference_batting_values)).to eq(
      2026 => {
        123456 => {
          "WAR" => 3.5, "Offense" => 23.0, "BaseRunning" => 1.6,
          "Defense" => -1.0, "OPS+" => 135.0
        }
      }
    )
  end

  it "parses Baseball-Reference pitcher WAR and runs above average values" do
    downloader = described_class.new(category: "pitching", start_year: 2025, end_year: 2026)
    csv_body = <<~CSV
      name_common,mlb_ID,year_ID,team_ID,runs_above_avg,WAR,ERA_plus
      Tarik Skubal,669373,2025,DET,42.455,6.3,167
      Tarik Skubal,669373,2026,DET,19.317,3.1,142
      Old Season,123456,2024,DET,10.0,2.0,120
    CSV
    response = instance_double(Net::HTTPSuccess, body: csv_body)
    allow(downloader).to receive(:request_csv).and_return(response)

    expect(downloader.send(:fetch_baseball_reference_values)).to eq(
      2025 => { 669373 => { "RAA" => 42.455, "WAR" => 6.3, "ERA+" => 167.0 } },
      2026 => { 669373 => { "RAA" => 19.317, "WAR" => 3.1, "ERA+" => 142.0 } }
    )
  end

  it "parses Statcast pitcher run values" do
    downloader = described_class.new(category: "pitching", start_year: 2025, end_year: 2025)
    csv_body = "\uFEFF" + <<~CSV
      "year","last_name, first_name","player_id","runs_all"
      "2025","Skubal, Tarik","669373",51.4083
    CSV
    response = instance_double(Net::HTTPSuccess, body: csv_body.b)
    allow(downloader).to receive(:request_csv).and_return(response)

    expect(downloader.send(:fetch_statcast_run_values, 2025)).to eq(
      669373 => { "PitchingRuns" => 51.4083 }
    )
  end

  it "sums FanGraphs DRS across a player's fielding positions" do
    downloader = described_class.new(category: "batting", start_year: 2026, end_year: 2026)
    response = instance_double(
      Net::HTTPSuccess,
      body: {
        "data" => [
          { "xMLBAMID" => 701678, "Pos" => "SS", "DRS" => 0 },
          { "xMLBAMID" => 701678, "Pos" => "3B", "DRS" => -1 },
          { "xMLBAMID" => 701678, "Pos" => "2B", "DRS" => -3 },
          { "xMLBAMID" => 682985, "Pos" => "CF", "DRS" => 4 }
        ]
      }.to_json
    )
    http = instance_double(Net::HTTP)
    allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
    allow(Net::HTTP).to receive(:new).and_return(http)
    allow(http).to receive(:use_ssl=)
    allow(http).to receive(:open_timeout=)
    allow(http).to receive(:read_timeout=)
    allow(http).to receive(:request).and_return(response)

    values = downloader.send(:fetch_fangraphs_fielding_values, 2026)

    expect(values.dig(701678, "DRS")).to eq(-4.0)
    expect(values.dig(682985, "DRS")).to eq(4.0)
    expect(JSON.parse(values.dig(701678, "fieldingByPosition"))).to include(
      hash_including("position" => "2B", "defensive_runs_saved" => -3.0)
    )
  end

  it "parses Baseball Savant OAA values using the yearly fielder leaderboard" do
    downloader = described_class.new(category: "batting", start_year: 2025, end_year: 2025)

    csv_body = <<~CSV
      player_name,playerId,outs_above_average
      Riley Greene,682985,3
      Jacob Misiorowski,669373,-1.5
    CSV
    response = instance_double(Net::HTTPSuccess, body: csv_body)
    allow(downloader).to receive(:request_csv) do |uri|
      expect(uri.query).to include("startYear=2025", "endYear=2025", "range=year", "csv=true")
      response
    end

    expect(downloader.send(:fetch_statcast_fielding_values, 2025)).to eq(
      682985 => { "OAA" => 3.0 },
      669373 => { "OAA" => -1.5 }
    )
  end

  it "calculates fielding percentage from MLB fielding chances and errors" do
    downloader = described_class.new(category: "batting", start_year: 2025, end_year: 2025)
    allow(downloader).to receive(:fetch_json).and_return(
      {
        "stats" => [
          { "playerId" => 682985, "teamAbbrev" => "DET", "positionAbbrev" => "CF", "games" => 100, "innings" => "850.1", "putOuts" => 118, "assists" => 0, "chances" => 120, "errors" => 2, "fielding" => ".983" },
          { "playerId" => 682985, "teamAbbrev" => "DET", "positionAbbrev" => "LF", "games" => 10, "innings" => "75.0", "putOuts" => 10, "assists" => 0, "chances" => 10, "errors" => 0, "fielding" => "1.000" }
        ]
      },
      { "stats" => [] }
    )

    values = downloader.send(:fetch_mlb_fielding_values, 2025)
    expect(values.dig(682985, "fieldingPercentage")).to eq(128.0 / 130)
    expect(JSON.parse(values.dig(682985, "fieldingByPosition"))).to include(
      hash_including("position" => "CF", "games" => 100, "fielding_percentage" => 0.983)
    )
  end

  it "derives reliable pitching rates from MLB season totals without overwriting source values" do
    downloader = described_class.new(category: "pitching", start_year: 2026, end_year: 2026)
    row = {
      "battersFaced" => 100, "strikeOuts" => 30, "baseOnBalls" => 8,
      "hits" => 20, "homeRuns" => 4, "hitByPitch" => 2, "runs" => 10,
      "babip" => ".250", "K%" => 0.31
    }

    downloader.send(:merge_mlb_derived_values, [ row ])

    expect(row).to include("K%" => 0.31, "BB%" => 0.08, "K-BB%" => 0.23, "K/BB" => 3.75, "BABIP" => 0.25)
    expect(row.fetch("LOB%")).to be_within(0.0001).of(20.0 / 24.4)
  end

  it "normalizes pitcher aliases and validates the year range" do
    bad_range = described_class.call(category: "pitching", start_year: 2026, end_year: 2025)

    expect(bad_range[:success]).to be(false)
    expect(bad_range[:message]).to eq("End year must be greater than or equal to start year")
  end
end
