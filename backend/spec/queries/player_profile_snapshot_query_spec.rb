require "rails_helper"

RSpec.describe PlayerProfileSnapshotQuery do
  it "calculates missing ERA-, FIP, and FIP- from pitching totals" do
    team = create_team
    player = create_player(team: team, attributes: { mlb_id: 765_432 })
    innings = create_stat_type(name: "inningsPitched", label: "IP", category: "pitching")
    earned_runs = create_stat_type(name: "earnedRuns", label: "ER", category: "pitching")
    home_runs = create_stat_type(name: "homeRuns", label: "HR", category: "pitching")
    walks = create_stat_type(name: "baseOnBalls", label: "BB", category: "pitching")
    strikeouts = create_stat_type(name: "strikeOuts", label: "SO", category: "pitching")
    era_plus = create_stat_type(name: "ERA+", label: "ERA+", category: "pitching")
    [
      [ innings, 100.0 ], [ earned_runs, 25.0 ], [ home_runs, 10.0 ], [ walks, 20.0 ],
      [ strikeouts, 100.0 ], [ era_plus, 125.0 ]
    ].each do |stat_type, value|
      create_player_season_stat(player: player, stat_type: stat_type, attributes: { team: team, season: 2026, value: value })
    end

    values = described_class.new(player: player, on: Date.new(2026, 8, 19)).result
      .dig(:advanced_stats, :seasons, 0, :values)

    expect(values[:era_minus]).to eq(80.0)
    expect(values[:fip]).to be_a(Float)
    expect(values[:fip_minus]).to be_a(Float)
  end

  it "fills missing pitcher value metrics from Statcast pitch data" do
    team = create_team(attributes: { abbreviation: "TST" })
    opponent = create_team(attributes: { abbreviation: "OPP" })
    player = create_player(team: team, attributes: { mlb_id: 654_321 })
    game = create_game(home_team: team, away_team: opponent, official_date: Date.new(2026, 7, 10), status: "final")
    GamePlayerPitchingLine.create!(
      game: game, player: player, team: team, opponent_team: opponent, home: true, starter: false,
      source_name: "spec", last_synced_at: Time.current
    )
    innings_type = create_stat_type(name: "inningsPitched", label: "IP", category: "pitching")
    create_player_season_stat(player: player, stat_type: innings_type, attributes: { team: team, season: 2026, value: 1.0 })
    PitchDatum.create!(
      game_id: game.id, game_pk: game.mlb_id, game_date: game.official_date, pitcher: player.mlb_id,
      at_bat_number: 1, pitch_number: 1, delta_home_win_exp: 0.08, delta_pitcher_run_exp: 0.25,
      raw_data: { "pitchData" => {} }
    )

    values = described_class.new(player: player, on: game.official_date).result
      .dig(:advanced_stats, :seasons, 0, :values)

    expect(values).to include(wpa: 0.08, re24: 0.25, shutdowns: 1, meltdowns: 0)
  end

  it "includes last 7, 15, and 30 game splits for batters and pitchers" do
    player = create_player(attributes: { mlb_id: 123_456 })
    dates = (1..16).map { |offset| Date.new(2026, 7, 1) + offset }
    dates.each_with_index do |date, index|
      game_pk = 900_000 + index
      PitchDatum.create!(
        game_pk: game_pk, game_date: date, batter: player.mlb_id, pitcher: player.mlb_id,
        at_bat_number: 1, pitch_number: 1, description: "called_strike", events: "", raw_data: { "pitchData" => {} }
      )
    end

    payload = described_class.new(player: player, on: dates.last).result(sections: [ "splits"])

    expect(payload.dig(:batter_splits, :dimensions).last(3).map { |dimension| dimension[:key] })
      .to eq(%w[last_7_games last_15_games last_30_games])
    expect(payload.dig(:pitcher_splits, :dimensions).last(3).map { |dimension| dimension[:key] })
      .to eq(%w[last_7_games last_15_games last_30_games])
  end

  it "returns enough recent batting and pitching game logs for the profile selector" do
    team = create_team(attributes: { abbreviation: "TST" })
    opponent = create_team(attributes: { abbreviation: "OPP" })
    player = create_player(team: team)

    11.times do |index|
      game = create_game(
        home_team: team,
        away_team: opponent,
        official_date: Date.new(2026, 4, 1) + index,
        status: "final"
      )
      GamePlayerBattingLine.create!(
        game: game, player: player, team: team, opponent_team: opponent, home: true,
        at_bats: 4, hits: 1, source_name: "spec", last_synced_at: Time.current
      )
    end

    6.times do |index|
      game = create_game(
        home_team: team,
        away_team: opponent,
        official_date: Date.new(2026, 5, 1) + index,
        status: "final"
      )
      GamePlayerPitchingLine.create!(
        game: game, player: player, team: team, opponent_team: opponent, home: true,
        innings_pitched: "6.0", decision: "W", source_name: "spec", last_synced_at: Time.current
      )
    end

    logs = described_class.new(player: player).result.fetch(:game_logs)

    expect(logs[:batting].length).to eq(11)
    expect(logs[:pitching].length).to eq(6)
    expect(logs[:batting].first[:date]).to eq(Date.new(2026, 4, 11))
    expect(logs[:pitching].first[:date]).to eq(Date.new(2026, 5, 6))
    expect(logs[:batting].first[:opponent]).to eq("@ OPP")
  end

  it "displays the team a retired player spent the most seasons with" do
    longest_team = create_team(name: "Detroit Tigers")
    recent_team = create_team(name: "Miami Marlins")
    player = create_player(team: recent_team)
    player.create_profile!(
      source_name: "MLB Stats API",
      last_synced_at: Time.current,
      raw_data: { "active" => false }
    )
    stat_type = create_stat_type(name: "gamesPlayed", label: "G", category: "batting")
    [ 2018, 2019, 2020 ].each do |season|
      create_player_season_stat(player: player, stat_type: stat_type, attributes: { team: longest_team, season: season, value: 100 })
    end
    [ 2021, 2022 ].each do |season|
      create_player_season_stat(player: player, stat_type: stat_type, attributes: { team: recent_team, season: season, value: 100 })
    end

    display_team = described_class.new(player: player).result.fetch(:display_team)

    expect(display_team).to include(id: longest_team.id, name: "Detroit Tigers")
  end

  it "keeps an active player's current membership team in the header" do
    cached_team = create_team
    current_team = create_team
    player = create_player(team: cached_team)
    player.create_profile!(
      source_name: "MLB Stats API",
      last_synced_at: Time.current,
      raw_data: { "active" => true }
    )
    create_team_membership(player: player, team: current_team, starts_on: Date.current - 1.month)

    display_team = described_class.new(player: player).result.fetch(:display_team)

    expect(display_team).to include(id: current_team.id)
  end

  it "returns mapped external player identifiers" do
    player = create_player(attributes: { mlb_id: 682_985 })
    PlayerIdMapping.create!(
      mlb_id: player.mlb_id,
      chadwick_id: "abc12345",
      chadwick_uuid: "abc12345-1234-4567-890a-123456789012",
      baseball_reference_id: "greenri03",
      fangraphs_id: "25976",
      imported_at: Time.current
    )

    external_ids = described_class.new(player: player).result.fetch(:external_ids)

    expect(external_ids).to eq(baseball_reference: "greenri03", fangraphs: "25976")
  end

  it "coalesces adjacent same-team roster windows into one organization tenure" do
    player = create_player
    team = player.team
    first = create_team_membership(
      player: player,
      team: team,
      starts_on: Date.new(2024, 12, 31),
      ends_on: Date.new(2025, 12, 30),
      roster_status: "active"
    )
    create_team_membership(
      player: player,
      team: team,
      starts_on: Date.new(2025, 12, 31),
      ends_on: Date.new(2026, 7, 13),
      roster_status: "active"
    )
    latest = create_team_membership(
      player: player,
      team: team,
      starts_on: Date.new(2026, 7, 14),
      roster_status: "active",
      source_status_description: "Active"
    )

    history = described_class.new(player: player, on: Date.new(2026, 7, 17)).result.fetch(:team_history)

    expect(history).to contain_exactly(
      hash_including(
        id: latest.id,
        starts_on: first.starts_on,
        ends_on: nil,
        current: true,
        roster_status: "active",
        source_status_description: "Active",
        team: hash_including(id: team.id)
      )
    )
  end

  it "keeps separate tenures when a player leaves and later returns to a team" do
    player = create_player
    original_team = player.team
    other_team = create_team
    create_team_membership(player: player, team: original_team, starts_on: Date.new(2024, 1, 1), ends_on: Date.new(2024, 6, 30))
    create_team_membership(player: player, team: other_team, starts_on: Date.new(2024, 7, 1), ends_on: Date.new(2024, 12, 31))
    create_team_membership(player: player, team: original_team, starts_on: Date.new(2025, 1, 1))

    history = described_class.new(player: player, on: Date.new(2025, 6, 1)).result.fetch(:team_history)

    expect(history.map { |tenure| tenure.dig(:team, :id) }).to eq([ original_team.id, other_team.id, original_team.id ])
    expect(history.first).to include(current: true, roster_status: "active")
    expect(history.drop(1)).to all(
      include(current: false, roster_status: "organization", source_status_description: "Organization tenure")
    )
  end

  it "closes a stale open transaction tenure when a later roster membership belongs to another team" do
    former_team = create_team
    current_team = create_team
    player = create_player(team: current_team)
    create_team_membership(
      player: player,
      team: former_team,
      starts_on: Date.new(2026, 8, 3),
      roster_status: "organization",
      source_name: "MLB Stats API transactions"
    )
    create_team_membership(
      player: player,
      team: current_team,
      starts_on: Date.new(2026, 8, 14),
      roster_status: "active",
      source_name: "MLB Stats API"
    )

    history = described_class.new(player: player, on: Date.new(2026, 8, 15)).result.fetch(:team_history)

    expect(history.map { |tenure| [ tenure.dig(:team, :id), tenure[:starts_on], tenure[:ends_on], tenure[:current] ] }).to eq(
      [
        [ current_team.id, Date.new(2026, 8, 14), nil, true ],
        [ former_team.id, Date.new(2026, 8, 3), Date.new(2026, 8, 13), false ]
      ]
    )
  end

  it "does not let a stale roster snapshot extend a transaction-derived tenure" do
    former_team = create_team
    current_team = create_team
    player = create_player(team: current_team)
    create_team_membership(
      player: player,
      team: former_team,
      starts_on: Date.new(2022, 8, 7),
      ends_on: Date.new(2025, 7, 30),
      roster_status: "organization",
      source_name: "MLB Stats API transactions"
    )
    create_team_membership(
      player: player,
      team: former_team,
      starts_on: Date.new(2024, 12, 31),
      ends_on: Date.new(2025, 12, 30),
      roster_status: "active"
    )
    create_team_membership(
      player: player,
      team: current_team,
      starts_on: Date.new(2025, 7, 31),
      roster_status: "organization",
      source_name: "MLB Stats API transactions"
    )

    history = described_class.new(player: player, on: Date.new(2026, 7, 17)).result.fetch(:team_history)
    former_tenure = history.find { |tenure| tenure.dig(:team, :id) == former_team.id }

    expect(former_tenure).to include(
      starts_on: Date.new(2022, 8, 7),
      ends_on: Date.new(2025, 7, 30),
      current: false,
      source_status_description: "Organization tenure"
    )
  end

  it "prefers a pitching overview for a player whose primary position is pitcher" do
    player = create_player
    pitcher = create_position(mlb_code: "1", abbreviation: "P", name: "Pitcher", position_type: "pitcher")
    create_player_position(player: player, position: pitcher, attributes: { is_primary: true })
    era = create_stat_type(name: "ERA", label: "ERA", category: "pitching")
    home_runs = create_stat_type(name: "homeRuns", label: "HR", category: "batting")
    create_player_season_stat(player: player, stat_type: era, attributes: { season: 2026, value: 2.85 })
    create_player_season_stat(player: player, stat_type: home_runs, attributes: { season: 2026, value: 1 })

    overview = described_class.new(player: player).result.fetch(:season_overview)

    expect(overview).to include(season: 2026, category: "pitching", preferred_category: "pitching")
    expect(overview.fetch(:stats)).to include(hash_including(key: "ERA", value: "2.85"))
    expect(overview.fetch(:stats)).not_to include(hash_including(key: "homeRuns"))
  end

  it "returns a stable empty overview when season statistics are unavailable" do
    player = create_player

    expect(described_class.new(player: player).result.fetch(:season_overview)).to eq(
      season: nil,
      category: "batting",
      preferred_category: "batting",
      stats: []
    )
  end

  it "totals counting stats and recalculates batting rates across stored seasons" do
    player = create_player
    definitions = {
      gamesPlayed: create_stat_type(name: "gamesPlayed", label: "G", category: "batting"),
      atBats: create_stat_type(name: "atBats", label: "AB", category: "batting"),
      hits: create_stat_type(name: "hits", label: "H", category: "batting"),
      doubles: create_stat_type(name: "doubles", label: "2B", category: "batting"),
      triples: create_stat_type(name: "triples", label: "3B", category: "batting"),
      homeRuns: create_stat_type(name: "homeRuns", label: "HR", category: "batting"),
      walks: create_stat_type(name: "baseOnBalls", label: "BB", category: "batting"),
      hitByPitch: create_stat_type(name: "hitByPitch", label: "HBP", category: "batting"),
      sacFlies: create_stat_type(name: "sacFlies", label: "SF", category: "batting"),
      avg: create_stat_type(name: "avg", label: "AVG", category: "batting"),
      obp: create_stat_type(name: "obp", label: "OBP", category: "batting"),
      slg: create_stat_type(name: "slg", label: "SLG", category: "batting"),
      ops: create_stat_type(name: "ops", label: "OPS", category: "batting")
    }
    season_values = {
      2025 => { gamesPlayed: 120, atBats: 400, hits: 100, doubles: 20, triples: 2, homeRuns: 10, walks: 40, hitByPitch: 5, sacFlies: 4, avg: 0.250, obp: 0.323, slg: 0.385, ops: 0.708 },
      2026 => { gamesPlayed: 60, atBats: 200, hits: 60, doubles: 10, triples: 1, homeRuns: 20, walks: 20, hitByPitch: 2, sacFlies: 2, avg: 0.300, obp: 0.366, slg: 0.660, ops: 1.026 }
    }

    season_values.each do |season, values|
      values.each do |key, value|
        create_player_season_stat(
          player: player,
          stat_type: definitions.fetch(key),
          attributes: { season: season, value: value }
        )
      end
    end

    career = described_class.new(player: player).result.fetch(:career_overview)
    stats = career.fetch(:stats).index_by { |stat| stat.fetch(:key) }
    seasons = career.fetch(:seasons).index_by { |row| row.fetch(:season) }

    expect(career).to include(
      category: "batting",
      first_season: 2025,
      last_season: 2026,
      season_count: 2
    )
    expect(stats.fetch("gamesPlayed").fetch(:value)).to eq("180")
    expect(stats.fetch("homeRuns").fetch(:value)).to eq("30")
    expect(stats.fetch("avg").fetch(:value)).to eq("0.267")
    expect(stats.fetch("obp").fetch(:value)).to eq("0.337")
    expect(stats.fetch("slg").fetch(:value)).to eq("0.477")
    expect(stats.fetch("ops").fetch(:value)).to eq("0.814")
    expect(career.fetch(:columns).map { |column| column.fetch(:key) }).to include("gamesPlayed", "homeRuns", "avg", "slg")
    expect(seasons.fetch(2025).fetch(:stats)).to include(
      hash_including(key: "gamesPlayed", value: "120"),
      hash_including(key: "homeRuns", value: "10"),
      hash_including(key: "avg", value: "0.250"),
      hash_including(key: "obp", value: "0.323"),
      hash_including(key: "ops", value: "0.708")
    )
    expect(seasons.fetch(2026).fetch(:stats)).to include(
      hash_including(key: "gamesPlayed", value: "60"),
      hash_including(key: "homeRuns", value: "20"),
      hash_including(key: "avg", value: "0.300"),
      hash_including(key: "obp", value: "0.366"),
      hash_including(key: "ops", value: "1.026")
    )
  end

  it "uses the imported batting average when it differs from the H/AB calculation" do
    player = create_player
    at_bats = create_stat_type(name: "atBats", label: "AB", category: "batting")
    hits = create_stat_type(name: "hits", label: "H", category: "batting")
    average = create_stat_type(name: "avg", label: "AVG", category: "batting")

    create_player_season_stat(player: player, stat_type: at_bats, attributes: { season: 2026, value: 494 })
    create_player_season_stat(player: player, stat_type: hits, attributes: { season: 2026, value: 160 })
    create_player_season_stat(player: player, stat_type: average, attributes: { season: 2026, value: 0.322 })

    snapshot = described_class.new(player: player).result

    expect(snapshot.dig(:season_overview, :stats)).to include(hash_including(key: "avg", value: "0.322"))
    expect(snapshot.dig(:career_overview, :seasons, 0, :stats)).to include(hash_including(key: "avg", value: "0.322"))
  end

  it "does not double team stats when identical scopes share a team id" do
    team = create_team(abbreviation: "TEX")
    player = create_player(team: team)
    games = StatType.find_or_create_by!(name: "gamesPlayed") { |stat| stat.label = "G"; stat.category = "batting" }
    at_bats = StatType.find_or_create_by!(name: "atBats") { |stat| stat.label = "AB"; stat.category = "batting" }
    hits = StatType.find_or_create_by!(name: "hits") { |stat| stat.label = "H"; stat.category = "batting" }

    [ [ "TEX", 120 ], [ "WAS", 120 ] ].each do |scope_key, value|
      create_player_season_stat(
        player: player,
        stat_type: games,
        attributes: { team: team, season: 2006, scope_key: scope_key, value: value }
      )
      create_player_season_stat(
        player: player,
        stat_type: at_bats,
        attributes: { team: team, season: 2006, scope_key: scope_key, value: 423 }
      )
      create_player_season_stat(
        player: player,
        stat_type: hits,
        attributes: { team: team, season: 2006, scope_key: scope_key, value: 121 }
      )
    end

    season = described_class.new(player: player).result.dig(:career_overview, :seasons, 0)

    expect(season.fetch(:team_rows).size).to eq(1)
    expect(season.fetch(:stats)).to include(
      hash_including(key: "gamesPlayed", value: "120"),
      hash_including(key: "atBats", value: "423"),
      hash_including(key: "hits", value: "121")
    )
  end

  it "combines baseball innings and recalculates career pitching rates" do
    player = create_player
    pitcher = create_position(mlb_code: "1", abbreviation: "P", name: "Pitcher", position_type: "pitcher")
    create_player_position(player: player, position: pitcher, attributes: { is_primary: true })
    definitions = {
      inningsPitched: create_stat_type(name: "inningsPitched", label: "IP", category: "pitching"),
      earnedRuns: create_stat_type(name: "ER", label: "ER", category: "pitching"),
      hits: create_stat_type(name: "hits", label: "H", category: "pitching"),
      walks: create_stat_type(name: "baseOnBalls", label: "BB", category: "pitching"),
      era: create_stat_type(name: "ERA", label: "ERA", category: "pitching"),
      whip: create_stat_type(name: "whip", label: "WHIP", category: "pitching"),
      atBats: create_stat_type(name: "atBats", label: "AB", category: "pitching"),
      avg: create_stat_type(name: "avg", label: "AVG", category: "pitching")
    }
    season_values = {
      2025 => { inningsPitched: 10.2, earnedRuns: 3, hits: 8, walks: 2, era: 2.53, whip: 0.94, atBats: 40, avg: 0.200 },
      2026 => { inningsPitched: 5.1, earnedRuns: 2, hits: 4, walks: 1, era: 3.38, whip: 0.94, atBats: 40, avg: 0.100 }
    }

    season_values.each do |season, values|
      values.each do |key, value|
        create_player_season_stat(
          player: player,
          stat_type: definitions.fetch(key),
          attributes: { season: season, value: value }
        )
      end
    end

    career = described_class.new(player: player).result.fetch(:career_overview)
    stats = career.fetch(:stats).index_by { |stat| stat.fetch(:key) }
    seasons = career.fetch(:seasons).index_by { |row| row.fetch(:season) }

    expect(career).to include(category: "pitching", season_count: 2)
    expect(stats.fetch("inningsPitched").fetch(:value)).to eq("16.0")
    expect(stats.fetch("ERA").fetch(:value)).to eq("2.81")
    expect(stats.fetch("whip").fetch(:value)).to eq("0.94")
    expect(stats.fetch("avg").fetch(:value)).to eq("0.150")
    expect(seasons.fetch(2025).fetch(:stats)).to include(hash_including(key: "inningsPitched", value: "10.2"))
    expect(seasons.fetch(2026).fetch(:stats)).to include(hash_including(key: "inningsPitched", value: "5.1"))
  end

  it "preserves imported defensive metrics when game lines replace mismatched batting totals" do
    team = create_team(abbreviation: "DET")
    opponent = create_team(abbreviation: "CLE")
    player = create_player(team: team)
    definitions = {
      games: create_stat_type(name: "gamesPlayed", label: "G", category: "batting"),
      average: create_stat_type(name: "avg", label: "AVG", category: "batting"),
      fielding_percentage: create_stat_type(name: "fieldingPercentage", label: "FPCT", category: "batting"),
      defense: create_stat_type(name: "Defense", label: "Def", category: "batting"),
      oaa: create_stat_type(name: "OAA", label: "OAA", category: "batting")
    }
    {
      games: 2,
      average: 0.250,
      fielding_percentage: 0.981,
      defense: -6.4,
      oaa: -9
    }.each do |key, value|
      create_player_season_stat(
        player: player,
        stat_type: definitions.fetch(key),
        attributes: { team: team, season: 2026, value: value, scope_type: "team", scope_key: "DET" }
      )
    end
    game = create_game(
      home_team: team,
      away_team: opponent,
      official_date: Date.new(2026, 8, 17),
      status: "final"
    )
    GamePlayerBattingLine.create!(
      game: game,
      player: player,
      team: team,
      opponent_team: opponent,
      home: true,
      starter: true,
      plate_appearances: 4,
      at_bats: 4,
      hits: 1,
      source_name: "MLB Stats API",
      last_synced_at: Time.current
    )
    PlayerSeasonFieldingStat.create!(
      player: player, team: team, season: 2026, team_abbreviation: "DET", position: "2B",
      games: 56, innings: 360.2, putouts: 64, assists: 99, fielding_errors: 3,
      fielding_percentage: 0.981928, defensive_runs_saved: -3, outs_above_average: -4,
      source_name: "FanGraphs fielding leaderboard", last_synced_at: Time.current
    )
    PlayerSeasonFieldingStat.create!(
      player: player, team: team, season: 2026, team_abbreviation: "DET", position: "3B",
      games: 24, innings: 131.1, putouts: 10, assists: 34, fielding_errors: 1,
      fielding_percentage: 0.977778, defensive_runs_saved: -1, outs_above_average: -4,
      source_name: "FanGraphs fielding leaderboard", last_synced_at: Time.current
    )
    PlayerSeasonFieldingStat.create!(
      player: player, team: team, season: 2026, team_abbreviation: "DET", position: "DH",
      games: 10, innings: nil, putouts: nil, assists: nil, fielding_errors: nil,
      fielding_percentage: nil, defensive_runs_saved: nil, outs_above_average: nil,
      source_name: "legacy fallback", last_synced_at: Time.current
    )


    defensive = described_class.new(player: player).result.fetch(:defensive_stats).fetch(:seasons).sole

    expect(defensive).to include(
      season: 2026,
      games: 1,
      fielding_percentage: 0.981,
      defensive_runs_saved: -4.0,
      outs_above_average: -9.0
    )

    expect(described_class.new(player: player).result.dig(:season_overview, :stats))
      .to include(hash_including(key: "avg", value: "0.25"))

    expect(defensive.fetch(:positions)).to eq([
      {
        position: "2B", games: 56, innings: "360.2",
        fielding_percentage: (163.0 / 166),
        defensive_runs_saved: -3.0, outs_above_average: -4.0
      },
      {
        position: "3B", games: 24, innings: "131.1",
        fielding_percentage: (44.0 / 45),
        defensive_runs_saved: -1.0, outs_above_average: -4.0
      }
    ])
  end

  it "returns grouped advanced batting rates by season and for the career" do
    player = create_player
    definitions = {
      pa: create_stat_type(name: "plateAppearances", label: "PA", category: "batting"),
      ab: create_stat_type(name: "atBats", label: "AB", category: "batting"),
      hits: create_stat_type(name: "hits", label: "H", category: "batting"),
      home_runs: create_stat_type(name: "homeRuns", label: "HR", category: "batting"),
      walks: create_stat_type(name: "baseOnBalls", label: "BB", category: "batting"),
      strikeouts: create_stat_type(name: "strikeOuts", label: "SO", category: "batting"),
      sacrifice_flies: create_stat_type(name: "sacFlies", label: "SF", category: "batting"),
      average: create_stat_type(name: "avg", label: "AVG", category: "batting"),
      slugging: create_stat_type(name: "slg", label: "SLG", category: "batting"),
      woba: create_stat_type(name: "wOBA", label: "wOBA", category: "batting"),
      wrc_plus: create_stat_type(name: "wRC+", label: "wRC+", category: "batting"),
      ops_plus: create_stat_type(name: "OPS+", label: "OPS+", category: "batting"),
      offense: create_stat_type(name: "Offense", label: "Off", category: "batting"),
      baserunning: create_stat_type(name: "BaseRunning", label: "BsR", category: "batting"),
      defense: create_stat_type(name: "Defense", label: "Def", category: "batting"),
      war: create_stat_type(name: "WAR", label: "WAR", category: "batting"),
      balls_in_play: create_stat_type(name: "ballsInPlay", label: "BIP", category: "batting"),
      ground_ball_percentage: create_stat_type(name: "GB%", label: "GB%", category: "batting"),
      fly_ball_percentage: create_stat_type(name: "FB%", label: "FB%", category: "batting"),
      line_drive_percentage: create_stat_type(name: "LD%", label: "LD%", category: "batting"),
      pull_percentage: create_stat_type(name: "Pull%", label: "Pull%", category: "batting"),
      center_percentage: create_stat_type(name: "Cent%", label: "Center%", category: "batting"),
      opposite_field_percentage: create_stat_type(name: "Oppo%", label: "Opposite-field%", category: "batting"),
      pitches: create_stat_type(name: "numberOfPitches", label: "P", category: "batting"),
      swing_percentage: create_stat_type(name: "Swing%", label: "Swing%", category: "batting"),
      chase_percentage: create_stat_type(name: "O-Swing%", label: "Chase%", category: "batting"),
      contact_percentage: create_stat_type(name: "Contact%", label: "Contact%", category: "batting"),
      zone_contact_percentage: create_stat_type(name: "Z-Contact%", label: "Zone Contact%", category: "batting"),
      swinging_strike_percentage: create_stat_type(name: "SwStr%", label: "SwStr%", category: "batting")
    }
    values = {
      2025 => { pa: 100, ab: 85, hits: 25, home_runs: 5, walks: 10, strikeouts: 20, sacrifice_flies: 2, average: 0.294, slugging: 0.529, woba: 0.370, wrc_plus: 130, ops_plus: 125, offense: 12, baserunning: 2, defense: -1, war: 3, balls_in_play: 60, ground_ball_percentage: 0.4, fly_ball_percentage: 0.35, line_drive_percentage: 0.25, pull_percentage: 0.42, center_percentage: 0.33, opposite_field_percentage: 0.25, pitches: 400, swing_percentage: 0.5, chase_percentage: 0.3, contact_percentage: 0.75, zone_contact_percentage: 0.82, swinging_strike_percentage: 0.125 },
      2026 => { pa: 200, ab: 170, hits: 45, home_runs: 10, walks: 20, strikeouts: 50, sacrifice_flies: 4, average: 0.265, slugging: 0.500, woba: 0.350, wrc_plus: 115, ops_plus: 112, offense: 18, baserunning: -1, defense: 3, war: 4, balls_in_play: 120, ground_ball_percentage: 0.45, fly_ball_percentage: 0.3, line_drive_percentage: 0.25, pull_percentage: 0.46, center_percentage: 0.31, opposite_field_percentage: 0.23, pitches: 800, swing_percentage: 0.47, chase_percentage: 0.25, contact_percentage: 0.8, zone_contact_percentage: 0.86, swinging_strike_percentage: 0.094 }
    }

    values.each do |season, season_values|
      season_values.each do |key, value|
        create_player_season_stat(player: player, stat_type: definitions.fetch(key), attributes: { season: season, value: value })
      end
    end

    snapshot = described_class.new(player: player).result
    advanced = snapshot.fetch(:advanced_stats)

    expect(snapshot.dig(:season_overview, :comparison_stats)).to contain_exactly(
      { key: "k_percentage", label: "K%", value: 0.25 },
      { key: "bb_percentage", label: "BB%", value: 0.1 }
    )
    expect(snapshot.dig(:career_overview, :comparison_stats)).to contain_exactly(
      { key: "k_percentage", label: "K%", value: (70.0 / 300) },
      { key: "bb_percentage", label: "BB%", value: 0.1 }
    )

    expect(advanced.fetch(:groups).map { |group| group.fetch(:label) }).to eq(
      [ "Plate discipline", "Batted-ball profile", "Rate statistics", "Run Creation & Value" ]
    )
    expect(advanced.fetch(:seasons).last.fetch(:values)).to include(
      bb_percentage: 0.1,
      k_percentage: 0.25,
      bb_per_k: 0.4,
      iso: 0.235,
      hr_per_fly_ball: (10.0 / (120 * 0.3)),
      woba: 0.35,
      wrc_plus: 115.0,
      ops_plus: 112.0,
      offensive_runs: 18.0,
      baserunning_runs: -1.0,
      defensive_value: 3.0,
      war: 4.0,
      ground_ball_percentage: 0.45,
      opposite_field_percentage: 0.23,
      swing_percentage: 0.47,
      chase_percentage: 0.25,
      swinging_strike_percentage: 0.094
    )
    expect(advanced.dig(:career, :values)).to include(
      bb_percentage: 0.1,
      k_percentage: (70.0 / 300),
      bb_per_k: (30.0 / 70),
      hr_per_fly_ball: (15.0 / (60 * 0.35 + 120 * 0.3)),
      woba: ((0.370 * 100 + 0.350 * 200) / 300),
      wrc_plus: 120.0,
      ops_plus: (349.0 / 3),
      offensive_runs: 30.0,
      baserunning_runs: 1.0,
      defensive_value: 2.0,
      war: 7.0,
      ground_ball_percentage: ((0.4 * 60 + 0.45 * 120) / 180),
      opposite_field_percentage: ((0.25 * 60 + 0.23 * 120) / 180),
      swing_percentage: ((0.5 * 400 + 0.47 * 800) / 1200),
      chase_percentage: ((0.3 * 400 + 0.25 * 800) / 1200),
      contact_percentage: ((0.75 * 400 + 0.8 * 800) / 1200),
      zone_contact_percentage: ((0.82 * 400 + 0.86 * 800) / 1200),
      swinging_strike_percentage: ((0.125 * 400 + 0.094 * 800) / 1200)
    )
  end

  it "returns stored position-level defensive stats for pitchers" do
    team = create_team(abbreviation: "DET")
    player = create_player(team: team)
    pitcher = create_position(mlb_code: "1", abbreviation: "P", name: "Pitcher", position_type: "pitcher")
    create_player_position(player: player, position: pitcher, attributes: { is_primary: true })
    games = create_stat_type(name: "G", label: "G", category: "pitching")
    create_player_season_stat(
      player: player,
      stat_type: games,
      attributes: { team: team, season: 2026, value: 19, scope_type: "team", scope_key: "DET" }
    )
    PlayerSeasonFieldingStat.create!(
      player: player, season: 2026, team_abbreviation: "2 TMS", position: "P",
      games: 19, innings: 113.2, putouts: 1, assists: 9, fielding_errors: 0,
      fielding_percentage: 1.0, defensive_runs_saved: -1, outs_above_average: nil,
      source_name: "FanGraphs fielding leaderboard", last_synced_at: Time.current
    )

    defensive = described_class.new(player: player).result.fetch(:defensive_stats).fetch(:seasons).sole

    expect(defensive).to include(
      season: 2026,
      games: 19,
      outs_above_average_applicable: false,
      fielding_percentage: 1.0,
      defensive_runs_saved: -1.0,
      outs_above_average: nil
    )
    expect(defensive.fetch(:positions)).to contain_exactly(
      {
        position: "P", games: 19, innings: "113.2", fielding_percentage: 1.0,
        defensive_runs_saved: -1.0, outs_above_average: nil
      }
    )
  end

  it "returns pitcher rate and outcome statistics by season and for the career" do
    player = create_player
    pitcher = create_position(mlb_code: "1", abbreviation: "P", name: "Pitcher", position_type: "pitcher")
    create_player_position(player: player, position: pitcher, attributes: { is_primary: true })
    definitions = {
      innings: create_stat_type(name: "inningsPitched", label: "IP", category: "pitching"),
      batters_faced: create_stat_type(name: "battersFaced", label: "BF", category: "pitching"),
      strikeouts: create_stat_type(name: "strikeOuts", label: "SO", category: "pitching"),
      walks: create_stat_type(name: "baseOnBalls", label: "BB", category: "pitching"),
      hit_batters: create_stat_type(name: "hitByPitch", label: "HBP", category: "pitching"),
      home_runs: create_stat_type(name: "homeRuns", label: "HR", category: "pitching"),
      runs: create_stat_type(name: "runs", label: "R", category: "pitching"),
      earned_runs: create_stat_type(name: "ER", label: "ER", category: "pitching"),
      babip: create_stat_type(name: "BABIP", label: "BABIP", category: "pitching"),
      lob_percentage: create_stat_type(name: "LOB%", label: "LOB%", category: "pitching"),
      fip: create_stat_type(name: "FIP", label: "FIP", category: "pitching"),
      era_minus: create_stat_type(name: "ERA-", label: "ERA-", category: "pitching"),
      fip_minus: create_stat_type(name: "FIP-", label: "FIP-", category: "pitching"),
      xfip: create_stat_type(name: "xFIP", label: "xFIP", category: "pitching"),
      xfip_minus: create_stat_type(name: "xFIP-", label: "xFIP-", category: "pitching"),
      siera: create_stat_type(name: "SIERA", label: "SIERA", category: "pitching"),
      xera: create_stat_type(name: "xERA", label: "xERA", category: "pitching"),
      woba_allowed: create_stat_type(name: "wOBAAllowed", label: "wOBA allowed", category: "pitching"),
      expected_woba_allowed: create_stat_type(name: "xwOBAAllowed", label: "Expected wOBA allowed", category: "pitching"),
      war: create_stat_type(name: "WAR", label: "WAR", category: "pitching"),
      ra9_war: create_stat_type(name: "RA9-Wins", label: "RA9-WAR", category: "pitching"),
      wpa: create_stat_type(name: "WPA", label: "WPA", category: "pitching"),
      wpa_per_li: create_stat_type(name: "WPA/LI", label: "WPA/LI", category: "pitching"),
      re24: create_stat_type(name: "RE24", label: "RE24", category: "pitching"),
      clutch: create_stat_type(name: "Clutch", label: "Clutch", category: "pitching"),
      rar: create_stat_type(name: "RAR", label: "RAR", category: "pitching"),
      raa: create_stat_type(name: "RAA", label: "RAA", category: "pitching"),
      pitching_runs: create_stat_type(name: "PitchingRuns", label: "Pitching runs", category: "pitching"),
      leverage_index: create_stat_type(name: "pLI", label: "pLI", category: "pitching"),
      shutdowns: create_stat_type(name: "SD", label: "SD", category: "pitching"),
      meltdowns: create_stat_type(name: "MD", label: "MD", category: "pitching")
    }
    values = {
      2025 => { innings: 100.0, batters_faced: 400, strikeouts: 100, walks: 40, hit_batters: 5, home_runs: 20, runs: 40, earned_runs: 30, babip: 0.300, lob_percentage: 0.720, era_minus: 80, fip: 4.00, fip_minus: 85, xfip: 4.20, xfip_minus: 90, siera: 3.8, xera: 3.6, woba_allowed: 0.31, expected_woba_allowed: 0.30, war: 4, ra9_war: 4.5, wpa: 3, wpa_per_li: 3.5, re24: 30, clutch: -0.5, rar: 40, raa: 25, pitching_runs: 23, leverage_index: 0.9, shutdowns: 3, meltdowns: 2 },
      2026 => { innings: 50.0, batters_faced: 200, strikeouts: 60, walks: 10, hit_batters: 2, home_runs: 5, runs: 15, earned_runs: 10, babip: 0.250, lob_percentage: 0.800, era_minus: 60, fip: 3.00, fip_minus: 70, xfip: 3.20, xfip_minus: 75, siera: 2.9, xera: 2.7, woba_allowed: 0.25, expected_woba_allowed: 0.27, war: 2, ra9_war: 2.5, wpa: 1, wpa_per_li: 1.5, re24: 15, clutch: 0.2, rar: 20, raa: 10, pitching_runs: 9, leverage_index: 1.1, shutdowns: 2, meltdowns: 1 }
    }

    values.each do |season, season_values|
      season_values.each do |key, value|
        create_player_season_stat(player: player, stat_type: definitions.fetch(key), attributes: { season: season, value: value })
      end
    end

    advanced = described_class.new(player: player).result.fetch(:advanced_stats)

    expect(advanced).to include(category: "pitching")
    expect(advanced.fetch(:groups).map { |group| group.fetch(:label) }).to eq(
      [ "Rate and outcome statistics", "Run prevention and expected performance", "Pitcher value" ]
    )
    expect(advanced.fetch(:seasons).last.fetch(:values)).to include(
      k_percentage: 0.3,
      bb_percentage: 0.05,
      k_minus_bb_percentage: 0.25,
      k_per_bb: 6.0,
      hbp_percentage: 0.01,
      hr_percentage: 0.025,
      babip: 0.25,
      lob_percentage: 0.8,
      era: 1.8,
      era_minus: 60.0,
      era_plus: (10_000.0 / 60),
      fip: 3.0,
      fip_minus: 70.0,
      xfip: 3.2,
      xfip_minus: 75.0,
      siera: 2.9,
      xera: 2.7,
      ra9: 2.7,
      runs_allowed_per_nine: 2.7,
      earned_runs_allowed_per_nine: 1.8,
      expected_woba_allowed: 0.27,
      woba_allowed: 0.25
    )
    expect(advanced.fetch(:seasons).last.fetch(:values)).to include(
      war: 2.0, ra9_war: 2.5, wpa: 1.0, wpa_per_li: 1.5, re24: 15.0,
      clutch: 0.2, runs_above_replacement: 20.0, runs_above_average: 10.0,
      pitching_runs: 9.0, leverage_index: 1.1, shutdowns: 2.0, meltdowns: 1.0
    )
    expect(advanced.dig(:career, :values)).to include(
      k_percentage: (160.0 / 600),
      bb_percentage: (50.0 / 600),
      k_minus_bb_percentage: (110.0 / 600),
      k_per_bb: 3.2,
      hbp_percentage: (7.0 / 600),
      hr_percentage: (25.0 / 600),
      babip: ((0.3 * 400 + 0.25 * 200) / 600),
      lob_percentage: ((0.72 * 100 + 0.8 * 50) / 150),
      era: 2.4,
      era_minus: (220.0 / 3),
      era_plus: (10_000.0 / (220.0 / 3)),
      fip: (11.0 / 3),
      fip_minus: 80.0,
      xfip: (58.0 / 15),
      xfip_minus: 85.0,
      siera: 3.5,
      xera: 3.3,
      ra9: 3.3,
      runs_allowed_per_nine: 3.3,
      earned_runs_allowed_per_nine: 2.4,
      expected_woba_allowed: 0.29,
      woba_allowed: 0.29
    )
    expect(advanced.dig(:career, :values)).to include(
      war: 6.0, ra9_war: 7.0, wpa: 4.0, wpa_per_li: 5.0, re24: 45.0,
      clutch: -0.3, runs_above_replacement: 60.0, runs_above_average: 35.0,
      pitching_runs: 32.0, leverage_index: ((0.9 * 400 + 1.1 * 200) / 600),
      shutdowns: 5.0, meltdowns: 3.0
    )
  end
end
