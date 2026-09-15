require "rails_helper"

RSpec.describe PlayerSeasonStatsLeaderboardQuery, type: :model do
  it "discovers available columns from stat types without scanning season-stat rows" do
    create_stat_type(name: "homeRuns", label: "HR", category: "batting")
    create_stat_type(name: "ops", label: "OPS", category: "batting")
    create_stat_type(name: "ERA", label: "ERA", category: "pitching")
    query = described_class.new(
      params: { filter: { category: "batting" } },
      relation: PlayerSeasonStat.none
    )

    expect(query.send(:available_stat_names)).to contain_exactly("homeRuns", "ops")
  end

  it "filters leaderboard rows by player position and exposes position facets" do
    team = create_team
    player = create_player(team: team)
    position = create_position(abbreviation: "QSS", name: "Query Shortstop", position_type: "infielder")
    create_player_position(player: player, position: position, attributes: { is_primary: true })
    stat_type = StatType.find_or_create_by!(name: "homeRuns") { |stat| stat.label = "HR"; stat.category = "batting" }
    create_player_season_stat(player: player, stat_type: stat_type, attributes: { season: 2024, value: 20 })

    query = described_class.new(params: { filter: { category: "batting", position_id: position.id } })

    expect(query.results.map { |row| row.dig(:player, :id) }).to eq([player.id])
    expect(query.metadata[:available_positions]).to include(
      id: position.id, abbreviation: "QSS", name: "Query Shortstop"
    )
  end

  it "returns player leaderboard rows with batting stats across columns" do
    tigers = create_team(
      mlb_id: 116,
      name: "Detroit Tigers",
      abbreviation: "DET",
      team_name: "Tigers",
      location_name: "Detroit",
      short_name: "Detroit",
      team_code: "det",
      file_code: "det"
    )
    dodgers = create_team(
      mlb_id: 119,
      name: "Los Angeles Dodgers",
      abbreviation: "LAD",
      team_name: "Dodgers",
      location_name: "Los Angeles",
      short_name: "Los Angeles",
      team_code: "lan",
      file_code: "la"
    )
    miguel = create_player(team: tigers, attributes: { mlb_id: 408234, first_name: "Miguel", last_name: "Cabrera" })
    shohei = create_player(team: dodgers, attributes: { mlb_id: 660271, first_name: "Shohei", last_name: "Ohtani" })
    [
      ["gamesPlayed", "G"],
      ["atBats", "AB"],
      ["runs", "R"],
      ["hits", "H"],
      ["doubles", "2B"],
      ["triples", "3B"],
      ["homeRuns", "HR"],
      ["rbi", "RBI"],
      ["baseOnBalls", "BB"],
      ["strikeOuts", "SO"],
      ["stolenBases", "SB"],
      ["caughtStealing", "CS"],
      ["avg", "AVG"],
      ["obp", "OBP"],
      ["slg", "SLG"],
      ["ops", "OPS"]
    ].each do |name, label|
      create_stat_type(name: name, label: label, category: "batting")
    end

    {
      "gamesPlayed" => "150",
      "atBats" => "540",
      "runs" => "88",
      "hits" => "162",
      "doubles" => "30",
      "triples" => "2",
      "homeRuns" => "24",
      "rbi" => "91",
      "baseOnBalls" => "60",
      "strikeOuts" => "102",
      "stolenBases" => "4",
      "caughtStealing" => "1",
      "avg" => ".300",
      "obp" => ".372",
      "slg" => ".515",
      "ops" => ".887"
    }.each do |name, value|
      create_player_season_stat(
        player: miguel,
        stat_type: StatType.find_by!(name: name, category: "batting"),
        attributes: { season: 2024, value: value }
      )
    end

    {
      "gamesPlayed" => "155",
      "atBats" => "560",
      "runs" => "102",
      "hits" => "171",
      "doubles" => "28",
      "triples" => "4",
      "homeRuns" => "41",
      "rbi" => "99",
      "baseOnBalls" => "88",
      "strikeOuts" => "118",
      "stolenBases" => "18",
      "caughtStealing" => "3",
      "avg" => ".305",
      "obp" => ".401",
      "slg" => ".612",
      "ops" => "1.013"
    }.each do |name, value|
      create_player_season_stat(
        player: shohei,
        stat_type: StatType.find_by!(name: name, category: "batting"),
        attributes: { season: 2024, value: value }
      )
    end

    query = described_class.new(
      params: {
        page: 1,
        per_page: 5,
        sort: "-homeRuns",
        filter: { category: "batting", season: 2024 }
      }
    )

    expect(query.results.map { |row| row.dig(:player, :full_name) }).to eq(["Shohei Ohtani", "Miguel Cabrera"])
    expect(query.results.first[:rank]).to eq(1)
    expect(query.results.first.dig(:stats, "homeRuns")).to eq("41.0")
    expect(query.results.first.dig(:stats, "ops")).to eq("1.013")
    expect(query.metadata[:total_count]).to eq(2)
    expect(query.metadata[:sort]).to eq("-homeRuns")
    expect(query.metadata[:category]).to eq("batting")
    expect(query.metadata[:data_range]).to eq(type: "season", start: 2024, end: 2024)
    expect(query.metadata[:available_seasons]).to eq([2024])
    expect(query.metadata[:available_teams]).to eq(
      [
        {
          id: tigers.id,
          mlb_id: 116,
          abbreviation: "DET",
          name: "Detroit Tigers",
          team_name: "Tigers",
          location_name: "Detroit",
          short_name: "Detroit"
        },
        {
          id: dodgers.id,
          mlb_id: 119,
          abbreviation: "LAD",
          name: "Los Angeles Dodgers",
          team_name: "Dodgers",
          location_name: "Los Angeles",
          short_name: "Los Angeles"
        }
      ]
    )
    expect(query.metadata[:columns].map { |column| column[:label] }).to include("HR", "OPS")
  end

  it "sorts batting leaderboard rows by strikeOuts numerically" do
    tigers = create_team(
      mlb_id: 116,
      name: "Detroit Tigers",
      abbreviation: "DET",
      team_name: "Tigers",
      location_name: "Detroit",
      short_name: "Detroit",
      team_code: "det",
      file_code: "det"
    )
    dodgers = create_team(
      mlb_id: 119,
      name: "Los Angeles Dodgers",
      abbreviation: "LAD",
      team_name: "Dodgers",
      location_name: "Los Angeles",
      short_name: "Los Angeles",
      team_code: "lan",
      file_code: "la"
    )
    miguel = create_player(team: tigers, attributes: { mlb_id: 408234, first_name: "Miguel", last_name: "Cabrera" })
    shohei = create_player(team: dodgers, attributes: { mlb_id: 660271, first_name: "Shohei", last_name: "Ohtani" })

    %w[gamesPlayed atBats runs hits doubles triples homeRuns rbi baseOnBalls strikeOuts stolenBases caughtStealing avg obp slg ops].each do |name|
      create_stat_type(name: name, label: name, category: "batting") unless StatType.exists?(name: name, category: "batting")
    end

    {
      "gamesPlayed" => "150",
      "atBats" => "540",
      "runs" => "88",
      "hits" => "162",
      "doubles" => "30",
      "triples" => "2",
      "homeRuns" => "24",
      "rbi" => "91",
      "baseOnBalls" => "60",
      "strikeOuts" => "12",
      "stolenBases" => "4",
      "caughtStealing" => "1",
      "avg" => ".300",
      "obp" => ".372",
      "slg" => ".515",
      "ops" => ".887"
    }.each do |name, value|
      create_player_season_stat(
        player: miguel,
        stat_type: StatType.find_by!(name: name, category: "batting"),
        attributes: { season: 2024, value: value }
      )
    end

    {
      "gamesPlayed" => "155",
      "atBats" => "560",
      "runs" => "102",
      "hits" => "171",
      "doubles" => "28",
      "triples" => "4",
      "homeRuns" => "41",
      "rbi" => "99",
      "baseOnBalls" => "88",
      "strikeOuts" => "2",
      "stolenBases" => "18",
      "caughtStealing" => "3",
      "avg" => ".305",
      "obp" => ".401",
      "slg" => ".612",
      "ops" => "1.013"
    }.each do |name, value|
      create_player_season_stat(
        player: shohei,
        stat_type: StatType.find_by!(name: name, category: "batting"),
        attributes: { season: 2024, value: value }
      )
    end

    query = described_class.new(
      params: {
        view: "leaderboard",
        sort: "-strikeOuts",
        filter: { category: "batting", season: 2024 }
      }
    )

    expect(query.results.map { |row| [row.dig(:player, :full_name), row.dig(:stats, "strikeOuts")] }).to eq([
      ["Miguel Cabrera", "12.0"],
      ["Shohei Ohtani", "2.0"]
    ])
  end

  it "orders single-player filtered leaderboard rows by season ascending" do
    tigers = create_team(
      mlb_id: 116,
      name: "Detroit Tigers",
      abbreviation: "DET",
      team_name: "Tigers",
      location_name: "Detroit",
      short_name: "Detroit",
      team_code: "det",
      file_code: "det"
    )
    al = create_player(team: tigers, attributes: { mlb_id: 116822, first_name: "Al", last_name: "Kaline" })

    %w[gamesPlayed homeRuns ops].each do |name|
      create_stat_type(name: name, label: name, category: "batting") unless StatType.exists?(name: name, category: "batting")
    end

    [
      [1967, 25, 0.952],
      [1965, 18, 0.859],
      [1966, 29, 0.926]
    ].each do |season, home_runs, ops|
      create_player_season_stat(
        player: al,
        stat_type: StatType.find_by!(name: "gamesPlayed", category: "batting"),
        attributes: { season: season, value: 125 }
      )
      create_player_season_stat(
        player: al,
        stat_type: StatType.find_by!(name: "homeRuns", category: "batting"),
        attributes: { season: season, value: home_runs }
      )
      create_player_season_stat(
        player: al,
        stat_type: StatType.find_by!(name: "ops", category: "batting"),
        attributes: { season: season, value: ops }
      )
    end

    query = described_class.new(
      params: {
        view: "leaderboard",
        sort: "-homeRuns",
        filter: { category: "batting", player_name: "Al Kaline" }
      }
    )

    expect(query.results.map { |row| [row[:season], row.dig(:stats, "homeRuns")] }).to eq([
      [1965, "18.0"],
      [1966, "29.0"],
      [1967, "25.0"]
    ])
  end

  it "sorts leaderboard rows by season when requested" do
    older_player = create_player(attributes: { first_name: "Older", last_name: "Season" })
    newer_player = create_player(attributes: { first_name: "Newer", last_name: "Season" })
    home_runs = create_stat_type(name: "homeRuns", label: "HR", category: "batting")
    create_player_season_stat(player: older_player, stat_type: home_runs, attributes: { season: 2024, value: 20 })
    create_player_season_stat(player: newer_player, stat_type: home_runs, attributes: { season: 2026, value: 18 })

    query = described_class.new(params: { sort: "-season", filter: { category: "batting" } })

    expect(query.results.map { |row| row[:season] }).to eq([ 2026, 2024 ])
    expect(query.metadata[:sort]).to eq("-season")
  end

  it "uses the MLB-style pitching column order and labels" do
    query = described_class.new(
      params: {
        filter: { category: "pitching" }
      }
    )

    expect(query.metadata[:columns].map { |column| [column[:key], column[:label]] }).to eq(
      [
        ["W", "W"],
        ["L", "L"],
        ["ERA", "ERA"],
        ["G", "G"],
        ["GS", "GS"],
        ["CG", "CG"],
        ["ShO", "SHO"],
        ["SV", "SV"],
        ["SVO", "SVO"],
        ["inningsPitched", "IP"],
        ["hits", "H"],
        ["runs", "R"],
        ["ER", "ER"],
        ["homeRuns", "HR"],
        ["hitByPitch", "HB"],
        ["baseOnBalls", "BB"],
        ["strikeOuts", "SO"],
        ["whip", "WHIP"],
        ["avg", "AVG"],
        ["WAR", "WAR"]
      ]
    )
  end

  it "fills pitching leaderboard stats from alias fields and derives earned runs when needed" do
    brewers = create_team(
      mlb_id: 158,
      name: "Milwaukee Brewers",
      abbreviation: "MIL",
      team_name: "Brewers",
      location_name: "Milwaukee",
      short_name: "Brewers",
      team_code: "mil",
      file_code: "mil"
    )
    jacob = create_player(team: brewers, attributes: { mlb_id: 694973, first_name: "Jacob", last_name: "Misiorowski" })

    [
      ["ERA", "ERA"],
      ["gamesPitched", "GP"],
      ["inningsPitched", "IP"],
      ["hits", "H"],
      ["runs", "R"],
      ["homeRuns", "HR"],
      ["hitByPitch", "HBP"],
      ["baseOnBalls", "BB"],
      ["strikeOuts", "SO"],
      ["whip", "WHIP"],
      ["avg", "AVG"]
    ].each do |name, label|
      create_stat_type(name: name, label: label, category: "pitching")
    end

    {
      "ERA" => "1.83",
      "gamesPitched" => "12",
      "inningsPitched" => "64.0",
      "hits" => "34",
      "runs" => "15",
      "homeRuns" => "4",
      "hitByPitch" => "5",
      "baseOnBalls" => "19",
      "strikeOuts" => "100",
      "whip" => "0.83",
      "avg" => "0.153"
    }.each do |name, value|
      create_player_season_stat(
        player: jacob,
        stat_type: StatType.find_by!(name: name, category: "pitching"),
        attributes: { season: 2026, value: value }
      )
    end

    query = described_class.new(
      params: {
        filter: { category: "pitching", season: 2026 }
      }
    )

    row = query.results.first

    expect(row.dig(:stats, "G")).to eq("12.0")
    expect(row.dig(:stats, "ER")).to eq("13.0")
    expect(row.dig(:stats, "homeRuns")).to eq("4.0")
    expect(row.dig(:stats, "hitByPitch")).to eq("5.0")
    expect(row.dig(:stats, "baseOnBalls")).to eq("19.0")
    expect(row.dig(:stats, "strikeOuts")).to eq("100.0")
    expect(query.metadata[:columns].map { |column| column[:key] }).to eq(
      %w[ERA G inningsPitched hits runs ER homeRuns hitByPitch baseOnBalls strikeOuts whip avg]
    )
  end

  it "shows the season team instead of the player's current team" do
    current_team = create_team(
      mlb_id: 136,
      name: "Seattle Mariners",
      abbreviation: "SEA",
      team_name: "Mariners",
      location_name: "Seattle",
      short_name: "Seattle",
      team_code: "sea",
      file_code: "sea"
    )
    historical_team = create_team(
      mlb_id: 116,
      name: "Detroit Tigers",
      abbreviation: "DET",
      team_name: "Tigers",
      location_name: "Detroit",
      short_name: "Detroit",
      team_code: "det",
      file_code: "det"
    )
    batting_player = create_player(team: current_team, attributes: { mlb_id: 123456, first_name: "Alex", last_name: "Mason" })
    pitching_player = create_player(team: current_team, attributes: { mlb_id: 684517, first_name: "Milt", last_name: "Wilcox" })

    %w[homeRuns ops W ERA inningsPitched strikeOuts].each do |name|
      create_stat_type(name: name, label: name, category: "batting") unless StatType.exists?(name: name, category: "batting")
      create_stat_type(name: name, label: name, category: "pitching") unless StatType.exists?(name: name, category: "pitching")
    end

    create_player_season_stat(
      player: batting_player,
      stat_type: StatType.find_by!(name: "homeRuns", category: "batting"),
      attributes: { team: historical_team, season: 2024, value: 31 }
    )
    create_player_season_stat(
      player: batting_player,
      stat_type: StatType.find_by!(name: "ops", category: "batting"),
      attributes: { team: historical_team, season: 2024, value: 0.912 }
    )

    {
      "W" => "17",
      "ERA" => "3.58",
      "inningsPitched" => "196.2",
      "strikeOuts" => "115"
    }.each do |name, value|
      create_player_season_stat(
        player: pitching_player,
        stat_type: StatType.find_by!(name: name, category: "pitching"),
        attributes: { team: historical_team, season: 1976, value: value }
      )
    end

    batting_query = described_class.new(
      params: {
        view: "leaderboard",
        filter: { category: "batting", player_name: "Alex Mason", season: 2024 }
      }
    )

    pitching_query = described_class.new(
      params: {
        view: "leaderboard",
        filter: { category: "pitching", player_name: "Milt Wilcox", season: 1976 }
      }
    )

    expect(batting_query.results.first.dig(:team, :abbreviation)).to eq("DET")
    expect(batting_query.results.first.dig(:team, :team_name)).to eq("Tigers")
    expect(pitching_query.results.first.dig(:team, :abbreviation)).to eq("DET")
    expect(pitching_query.results.first.dig(:team, :team_name)).to eq("Tigers")
  end

  it "filters by historical season team id instead of player's current team" do
    current_team = create_team(
      mlb_id: 136,
      name: "Seattle Mariners",
      abbreviation: "SEA",
      team_name: "Mariners",
      location_name: "Seattle",
      short_name: "Seattle",
      team_code: "sea",
      file_code: "sea"
    )
    historical_team = create_team(
      mlb_id: 116,
      name: "Detroit Tigers",
      abbreviation: "DET",
      team_name: "Tigers",
      location_name: "Detroit",
      short_name: "Detroit",
      team_code: "det",
      file_code: "det"
    )
    player = create_player(team: current_team, attributes: { mlb_id: 555555, first_name: "Casey", last_name: "History" })

    %w[homeRuns ops].each do |name|
      create_stat_type(name: name, label: name, category: "batting") unless StatType.exists?(name: name, category: "batting")
    end

    create_player_season_stat(
      player: player,
      stat_type: StatType.find_by!(name: "homeRuns", category: "batting"),
      attributes: { team: historical_team, season: 2024, value: 29 }
    )
    create_player_season_stat(
      player: player,
      stat_type: StatType.find_by!(name: "ops", category: "batting"),
      attributes: { team: historical_team, season: 2024, value: 0.901 }
    )

    query = described_class.new(
      params: {
        view: "leaderboard",
        filter: { category: "batting", season: 2024, team_id: historical_team.id }
      }
    )

    expect(query.results.map { |row| row.dig(:player, :full_name) }).to eq(["Casey History"])
    expect(query.results.first.dig(:team, :abbreviation)).to eq("DET")
  end

  it "supports combined scope rows with scope filters" do
    player = create_player(attributes: { mlb_id: 777888, first_name: "Taylor", last_name: "Scope" })
    create_stat_type(name: "homeRuns", label: "HR", category: "batting") unless StatType.exists?(name: "homeRuns", category: "batting")
    create_stat_type(name: "ops", label: "OPS", category: "batting") unless StatType.exists?(name: "ops", category: "batting")

    create_player_season_stat(
      player: player,
      stat_type: StatType.find_by!(name: "homeRuns", category: "batting"),
      attributes: { season: 2024, team: nil, scope_type: "combined", scope_key: "TOT", value: 33 }
    )
    create_player_season_stat(
      player: player,
      stat_type: StatType.find_by!(name: "ops", category: "batting"),
      attributes: { season: 2024, team: nil, scope_type: "combined", scope_key: "TOT", value: 0.931 }
    )

    query = described_class.new(
      params: {
        filter: { category: "batting", season: 2024, scope_type: "combined", scope_key: "TOT" }
      }
    )

    expect(query.results.map { |row| row.dig(:player, :full_name) }).to eq(["Taylor Scope"])
    expect(query.results.first.dig(:scope, :type)).to eq("combined")
    expect(query.results.first.dig(:scope, :key)).to eq("TOT")
    expect(query.results.first.dig(:team, :abbreviation)).to eq("TOT")
  end
end
