require "rails_helper"

RSpec.describe MlbTradeImporter do
  let(:padres) { create_team(mlb_id: 135, name: "San Diego Padres", abbreviation: "SD") }
  let(:nationals) { create_team(mlb_id: 120, name: "Washington Nationals", abbreviation: "WSH") }
  let(:wood) { create_player(team: padres, attributes: { mlb_id: 695_578, first_name: "James", last_name: "Wood" }) }
  let(:fetched_at) { Time.zone.parse("2026-08-17 18:00:00") }

  def transaction(player_id:, player_name:, from:, to:)
    {
      "id" => 642_337,
      "person" => { "id" => player_id, "fullName" => player_name },
      "fromTeam" => { "id" => from.mlb_id, "name" => from.name },
      "toTeam" => { "id" => to.mlb_id, "name" => to.name },
      "date" => "2022-08-02",
      "typeCode" => "TR",
      "typeDesc" => "Trade",
      "description" => "Washington Nationals traded Juan Soto and Josh Bell to San Diego Padres for six players."
    }
  end

  it "persists one trade with every structured participant and available local links" do
    wood
    payload = {
      "transactions" => [
        transaction(player_id: 695_578, player_name: "James Wood", from: padres, to: nationals),
        transaction(player_id: 665_742, player_name: "Juan Soto", from: nationals, to: padres),
        transaction(player_id: 0, player_name: "Cash considerations", from: nationals, to: padres).merge("person" => nil)
      ]
    }

    first = described_class.call(payload: payload, source_url: "https://example.test/trade", fetched_at: fetched_at)
    second = described_class.call(payload: payload, source_url: "https://example.test/trade", fetched_at: fetched_at + 1.hour)

    expect(first[:success]).to be(true)
    expect(second[:success]).to be(true)
    expect(Trade.count).to eq(1)
    expect(TradeParticipant.count).to eq(2)

    trade = Trade.sole
    expect(trade).to have_attributes(
      mlb_transaction_id: 642_337,
      occurred_on: Date.new(2022, 8, 2),
      source_name: "MLB Stats API transactions",
      last_synced_at: fetched_at + 1.hour
    )
    expect(trade.raw_data).to eq(payload)
    expect(trade.trade_participants.find_by!(player_mlb_id: wood.mlb_id)).to have_attributes(
      player: wood,
      player_name: "James Wood",
      from_team: padres,
      to_team: nationals
    )
    expect(trade.trade_participants.find_by!(player_mlb_id: 665_742)).to have_attributes(
      player: nil,
      player_name: "Juan Soto",
      from_team: nationals,
      to_team: padres
    )
  end

  it "generates a description when MLB omits one" do
    payload = {
      "transactions" => [
        transaction(player_id: 695_578, player_name: "James Wood", from: padres, to: nationals).merge("description" => nil)
      ]
    }

    result = described_class.call(payload: payload, fetched_at: fetched_at)

    expect(result[:success]).to be(true)
    expect(Trade.sole.description).to eq("San Diego Padres traded James Wood to Washington Nationals.")
  end

  it "rejects rows that do not belong to one trade" do
    payload = {
      "transactions" => [
        transaction(player_id: 695_578, player_name: "James Wood", from: padres, to: nationals),
        transaction(player_id: 665_742, player_name: "Juan Soto", from: nationals, to: padres).merge("id" => 999)
      ]
    }

    result = described_class.call(payload: payload, fetched_at: fetched_at)

    expect(result[:success]).to be(false)
    expect(result.dig(:data, :errors)).to include("Trade transactions must share one MLB transaction id")
    expect(Trade.count).to eq(0)
  end
end
