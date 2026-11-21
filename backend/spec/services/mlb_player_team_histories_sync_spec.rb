require "rails_helper"

RSpec.describe MlbPlayerTeamHistoriesSync do
  it "synchronizes selected players and aggregates transaction and tenure counts" do
    first = create_player(attributes: { mlb_id: 656_427 })
    create_player(attributes: { mlb_id: 669_360 })
    allow(MlbPlayerTransactionsDownloader).to receive(:call).and_return(
      success: true,
      data: { payload: { "transactions" => [] }, source_url: "https://example.test", fetched_at: Time.current.iso8601 }
    )
    allow(MlbPlayerTeamHistoryImporter).to receive(:call).and_return(
      success: true,
      data: { transaction_count: 8, tenure_count: 5 }
    )

    result = described_class.call(mlb_ids: first.mlb_id)

    expect(result[:success]).to be(true)
    expect(result[:data]).to include(
      selected_player_count: 1,
      synchronized_player_count: 1,
      transaction_count: 8,
      tenure_count: 5
    )
    expect(MlbPlayerTransactionsDownloader).to have_received(:call).with(player_mlb_id: first.mlb_id)
  end

  it "counts the selected players before a limited sync starts" do
    3.times { create_player }

    expect(described_class.selected_player_count(limit: 2)).to eq(2)
    expect(described_class.selected_player_count(mlb_ids: "2001,2003")).to eq(2)
  end

  it "selects only players with activity in the requested season" do
    stats_player = create_player
    roster_player = create_player
    transaction_player = create_player
    old_player = create_player
    create_player_season_stat(player: stats_player, attributes: { season: 2026 })
    create_team_membership(player: roster_player, team: roster_player.team,
      attributes: { starts_on: Date.new(2026, 4, 1), ends_on: Date.new(2026, 8, 1) })
    create_team_membership(player: transaction_player, team: transaction_player.team,
      attributes: { starts_on: Date.new(2026, 1, 1), source_name: "MLB Stats API transactions" })
    create_player_season_stat(player: old_player, attributes: { season: 2025 })
    allow(MlbPlayerTransactionsDownloader).to receive(:call).and_return(
      success: true,
      data: { payload: { "transactions" => [] }, source_url: "https://example.test", fetched_at: Time.current.iso8601 }
    )
    allow(MlbPlayerTeamHistoryImporter).to receive(:call).and_return(success: true, data: { transaction_count: 0, tenure_count: 0 })

    expect(described_class.selected_player_count(season: 2026)).to eq(3)
    result = described_class.call(season: 2026)

    expect(result.dig(:data, :selected_player_count)).to eq(3)
    expect(MlbPlayerTransactionsDownloader).not_to have_received(:call).with(hash_including(player_mlb_id: old_player.mlb_id))
    expect(described_class.selected_player_count(season: 2026, mlb_ids: old_player.mlb_id)).to eq(1)
  end

  it "limits a seasonal sync to transactions dated within that season" do
    player = create_player
    allow(MlbPlayerTransactionsDownloader).to receive(:call).and_return(
      success: true,
      data: { payload: { "transactions" => [
        { "id" => 1, "date" => "2025-11-01", "typeCode" => "DFA" },
        { "id" => 2, "date" => "2026-11-01", "typeCode" => "DFA" }
      ] }, source_url: "https://example.test", fetched_at: Time.current.iso8601 }
    )
    allow(MlbPlayerTeamHistoryImporter).to receive(:call).and_return(
      success: true, data: { transaction_count: 1, tenure_count: 0 }
    )

    result = described_class.call(mlb_ids: player.mlb_id, season: 2025)

    expect(MlbPlayerTransactionsDownloader).to have_received(:call).with(
      player_mlb_id: player.mlb_id, start_date: Date.new(2025, 1, 1),
      end_date: Date.new(2025, 12, 31)
    )
    expect(MlbPlayerTeamHistoryImporter).to have_received(:call).with(
      hash_including(season: 2025, payload: { "transactions" => [ { "id" => 1, "date" => "2025-11-01", "typeCode" => "DFA" } ] })
    )
    expect(result.dig(:data, :season)).to eq(2025)
  end
end
