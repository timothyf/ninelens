require "rails_helper"

RSpec.describe OffseasonTransactionsQuery do
  it "returns every offseason trade and signing in newest-first order" do
    team = create_team(name: "Detroit Tigers", abbreviation: "DET")
    now = Time.current
    Player.insert_all!((1..51).map do |number|
      { mlb_id: 800_000 + number, first_name: "Player", last_name: number.to_s,
        team_id: team.id, created_at: now, updated_at: now }
    end)
    player_ids = Player.where(mlb_id: 800_001..800_051).pluck(:id)
    TeamMembership.insert_all!(player_ids.map do |player_id|
      { player_id: player_id, team_id: team.id, starts_on: Date.new(2026, 11, 20),
        roster_status: "organization", source_name: MlbPlayerTeamHistoryImporter::SOURCE_NAME,
        last_synced_at: now, raw_data: { "start_transaction" => { "typeCode" => "SFA" } },
        created_at: now, updated_at: now }
    end)
    Trade.create!(mlb_transaction_id: 42_001, occurred_on: Date.new(2026, 11, 21),
      description: "A November trade", source_name: "MLB Stats API transactions", last_synced_at: now)
    Trade.create!(mlb_transaction_id: 42_002, occurred_on: Date.new(2026, 9, 21),
      description: "A September trade", source_name: "MLB Stats API transactions", last_synced_at: now)

    result = described_class.new(on: Date.new(2026, 11, 25)).result

    expect(result).to include(season: 2026, as_of: Date.new(2026, 11, 25))
    expect(result[:transactions].length).to eq(52)
    expect(result[:transactions].first).to include(type: "Trade", description: "A November trade")
    expect(result[:transactions].count { |move| move[:type] == "Signing" }).to eq(51)
    expect(result[:transactions]).not_to include(include(description: "A September trade"))
    expect(OffseasonBriefingQuery.new(on: Date.new(2026, 11, 25)).result[:recent_moves])
      .to eq(result[:transactions].first(5))
  end
end
