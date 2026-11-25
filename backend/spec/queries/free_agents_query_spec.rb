require "rails_helper"

RSpec.describe FreeAgentsQuery do
  it "lists every unsigned free agent once and separates latest batter and pitcher stats" do
    team = create_team(abbreviation: "DET")
    new_team = create_team(abbreviation: "LAD")
    batter = create_player(team: team, attributes: { first_name: "Alex", last_name: "Batter" })
    pitcher = create_player(team: team, attributes: { first_name: "Pat", last_name: "Pitcher" })
    signed = create_player(team: team, attributes: { first_name: "Sam", last_name: "Signed" })
    create_player_profile(player: batter, attributes: { birth_date: Date.new(2000, 11, 20) })
    create_player_profile(player: pitcher, attributes: { birth_date: Date.new(2000, 11, 22) })
    [ batter, pitcher, signed ].each do |player|
      create_team_membership(player: player, team: team,
        starts_on: Date.new(2026, 3, 1), ends_on: Date.new(2026, 10, 30),
        source_name: MlbPlayerTeamHistoryImporter::SOURCE_NAME, roster_status: "organization",
        raw_data: { "end_transaction" => { "typeDesc" => "Declared Free Agency" } })
    end
    create_team_membership(player: signed, team: new_team,
      starts_on: Date.new(2026, 11, 2), source_name: MlbPlayerTeamHistoryImporter::SOURCE_NAME,
      roster_status: "organization")
    create_player_position(player: batter, position: create_position(abbreviation: "1B"),
      attributes: { season: 2026, is_primary: true })
    create_player_position(player: pitcher, position: create_position(abbreviation: "P", position_type: "pitcher"),
      attributes: { season: 2026, is_primary: true })
    { "AVG" => 0.285, "OBP" => 0.360, "SLG" => 0.510, "homeRuns" => 28, "RBI" => 91 }.each do |name, value|
      create_player_season_stat(player: batter, stat_type: create_stat_type(name: name, category: "batting"),
        attributes: { season: 2026, scope_type: "team", scope_key: "DET", value: value })
    end
    { "W" => 12, "L" => 7, "ERA" => 2.72, "WHIP" => 0.96, "inningsPitched" => 175.1, "strikeOuts" => 190 }.each do |name, value|
      create_player_season_stat(player: pitcher, stat_type: create_stat_type(name: name, category: "pitching"),
        attributes: { season: 2026, scope_type: "team", scope_key: "DET", value: value })
    end

    result = described_class.new(on: Date.new(2026, 11, 21)).result

    expect(result[:season]).to eq(2026)
    expect(result[:batters].map { |entry| entry[:player_id] }).to eq([ batter.id ])
    expect(result[:pitchers].map { |entry| entry[:player_id] }).to eq([ pitcher.id ])
    expect(result[:batters].first).to include(position: "1B", former_team: "DET", age: 26)
    expect(result[:pitchers].first).to include(age: 25)
    expect(result[:batters].first.dig(:stat_line, :values)).to include("AVG" => 0.285, "HR" => 28.0, "RBI" => 91.0)
    expect(result[:pitchers].first.dig(:stat_line, :values)).to include("W" => 12.0, "ERA" => 2.72, "IP" => 175.1, "SO" => 190.0)
  end
end
