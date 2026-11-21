require "rails_helper"

RSpec.describe OffseasonBriefingQuery do
  it "shows stored winter moves, confirmed free agents, and awards with the prior season" do
    team = create_team(mlb_id: 116, name: "Detroit Tigers", abbreviation: "DET")
    other = create_team(mlb_id: 119, name: "Los Angeles Dodgers", abbreviation: "LAD")
    agent = create_player(team: team, attributes: { first_name: "Alex", last_name: "Agent" })
    signed = create_player(team: other, attributes: { first_name: "Sam", last_name: "Signed" })
    create_team_membership(player: agent, team: team, starts_on: Date.new(2026, 3, 1),
      ends_on: Date.new(2026, 10, 30), roster_status: "organization",
      source_name: MlbPlayerTeamHistoryImporter::SOURCE_NAME,
      raw_data: { "end_transaction" => { "typeDesc" => "Declared Free Agency" } })
    create_team_membership(player: signed, team: team, starts_on: Date.new(2026, 3, 1),
      ends_on: Date.new(2026, 10, 30), roster_status: "organization",
      source_name: MlbPlayerTeamHistoryImporter::SOURCE_NAME,
      raw_data: { "end_transaction" => { "typeDesc" => "Elected Free Agency" } })
    create_team_membership(player: signed, team: other, starts_on: Date.new(2026, 11, 5),
      roster_status: "organization", source_name: MlbPlayerTeamHistoryImporter::SOURCE_NAME,
      raw_data: { "start_transaction" => { "typeCode" => "SFA" } })
    war = create_stat_type(name: "WAR", category: "batting")
    position = create_position(abbreviation: "1B")
    create_player_position(player: agent, position: position, attributes: { season: 2026, is_primary: true })
    { "AVG" => 0.285, "OBP" => 0.360, "SLG" => 0.510 }.each do |name, value|
      stat_type = create_stat_type(name: name, category: "batting")
      create_player_season_stat(player: agent, stat_type: stat_type,
        attributes: { season: 2026, scope_type: "team", scope_key: "DET", value: value })
    end
    create_player_season_stat(player: agent, stat_type: war,
      attributes: { season: 2024, scope_type: "combined", scope_key: "MLB", value: 2.1 })
    create_player_season_stat(player: agent, stat_type: war,
      attributes: { season: 2025, scope_type: "combined", scope_key: "MLB", value: 3.0 })
    create_player_season_stat(player: agent, stat_type: war,
      attributes: { season: 2026, scope_type: "combined", scope_key: "MLB", value: 4.2 })
    SeasonAward.create!(season: 2026, award_id: "ALMVP", award_name: "AL MVP",
      player_mlb_id: agent.mlb_id, player_name: agent.full_name,
      source_url: "https://example.test/award")
    SeasonAward.create!(season: 2026, award_id: "ALROY", award_name: "AL Rookie of the Year",
      player_mlb_id: agent.mlb_id, player_name: agent.full_name,
      source_url: "https://example.test/award")
    SeasonAward.create!(season: 2026, award_id: "NLROY", award_name: "NL Rookie of the Year",
      player_mlb_id: signed.mlb_id, player_name: signed.full_name,
      source_url: "https://example.test/award")
    Trade.create!(mlb_transaction_id: 9_001, occurred_on: Date.new(2026, 11, 3),
      description: "A winter trade", source_name: "MLB Stats API transactions",
      last_synced_at: Time.current)

    briefing = described_class.new(on: Date.new(2027, 1, 10)).result

    expect(briefing[:season]).to eq(2026)
    expect(briefing[:recent_moves].map { |move| move[:type] }).to include("Trade", "Signing")
    expect(briefing[:free_agents]).to contain_exactly(include(
      player_id: agent.id, position: "1B", war: 4.2, war_season: 2026, experience_years: 3,
      stat_line: { season: 2026, type: "batting", values: { "AVG" => 0.285, "OBP" => 0.36, "SLG" => 0.51 } }
    ))
    expect(briefing[:awards]).to include(include(name: "AL MVP", player_id: agent.id))
    expect(briefing[:awards]).to include(include(name: "AL Rookie of the Year", player_id: agent.id))
    expect(briefing[:awards]).to include(include(name: "NL Rookie of the Year", player_id: signed.id))
  end

  it "does not show the offseason briefing during the season" do
    expect(described_class.new(on: Date.new(2026, 7, 16)).result).to be_nil
  end

  it "uses the latest available WAR season when the completed season has no WAR" do
    team = create_team(mlb_id: 116, name: "Detroit Tigers", abbreviation: "DET")
    player = create_player(team: team)
    create_team_membership(player: player, team: team, starts_on: Date.new(2025, 3, 1),
      ends_on: Date.new(2026, 10, 30), roster_status: "organization",
      source_name: MlbPlayerTeamHistoryImporter::SOURCE_NAME,
      raw_data: { "end_transaction" => { "typeDesc" => "Declared Free Agency" } })
    war = create_stat_type(name: "WAR", category: "batting")
    hits = create_stat_type(name: "hits", category: "batting")
    create_player_season_stat(player: player, stat_type: war,
      attributes: { season: 2025, scope_type: "combined", scope_key: "MLB", value: 3.5 })
    create_player_season_stat(player: player, stat_type: hits,
      attributes: { season: 2026, scope_type: "combined", scope_key: "MLB", value: 100 })

    agent = described_class.new(on: Date.new(2026, 11, 20)).result[:free_agents].first

    expect(agent).to include(war: 3.5, war_season: 2025, experience_years: 2)
  end

  it "includes high-WAR free agents whose departure precedes 150 other departures" do
    team = create_team(mlb_id: 116, name: "Detroit Tigers", abbreviation: "DET")
    star = create_player(team: team, attributes: { first_name: "Tarik", last_name: "Skubal" })
    create_team_membership(player: star, team: team, starts_on: Date.new(2026, 3, 1),
      ends_on: Date.new(2026, 10, 28), roster_status: "organization",
      source_name: MlbPlayerTeamHistoryImporter::SOURCE_NAME,
      raw_data: { "end_transaction" => { "typeDesc" => "Declared Free Agency" } })
    war = create_stat_type(name: "WAR", category: "pitching")
    position = create_position(abbreviation: "P", position_type: "pitcher")
    create_player_position(player: star, position: position, attributes: { season: 2026, is_primary: true })
    { "W" => 12, "L" => 7, "ERA" => 2.72, "WHIP" => 0.96 }.each do |name, value|
      stat_type = create_stat_type(name: name, category: "pitching")
      create_player_season_stat(player: star, stat_type: stat_type,
        attributes: { season: 2026, scope_type: "team", scope_key: "DET", value: value })
    end
    create_player_season_stat(player: star, stat_type: war,
      attributes: { season: 2026, scope_type: "combined", scope_key: "MLB", value: 5.2 })

    now = Time.current
    Player.insert_all!((1..150).map do |number|
      { mlb_id: 900_000 + number, first_name: "Other", last_name: number.to_s,
        team_id: team.id, created_at: now, updated_at: now }
    end)
    player_ids = Player.where(mlb_id: 900_001..900_150).pluck(:id)
    TeamMembership.insert_all!(player_ids.map do |player_id|
      { player_id: player_id, team_id: team.id, starts_on: Date.new(2026, 10, 29),
        ends_on: Date.new(2026, 11, 19), roster_status: "organization",
        source_name: MlbPlayerTeamHistoryImporter::SOURCE_NAME, last_synced_at: now,
        raw_data: { "end_transaction" => { "typeDesc" => "Released" } },
        created_at: now, updated_at: now }
    end)

    agents = described_class.new(on: Date.new(2026, 11, 20)).result[:free_agents]

    expect(agents).to include(include(player_id: star.id, position: "P", war: 5.2,
      stat_line: { season: 2026, type: "pitching", values: { "W" => 12.0, "L" => 7.0, "ERA" => 2.72, "WHIP" => 0.96 } }))
  end
end
