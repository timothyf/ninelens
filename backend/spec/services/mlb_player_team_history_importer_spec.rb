require "rails_helper"

RSpec.describe MlbPlayerTeamHistoryImporter do
  it "reconstructs major-league organization tenures from official transactions" do
    cardinals = create_team(mlb_id: 138, name: "St. Louis Cardinals", abbreviation: "STL")
    orioles = create_team(mlb_id: 110, name: "Baltimore Orioles", abbreviation: "BAL")
    tigers = create_team(mlb_id: 116, name: "Detroit Tigers", abbreviation: "DET")
    dodgers = create_team(mlb_id: 119, name: "Los Angeles Dodgers", abbreviation: "LAD")
    player = create_player(team: tigers, attributes: { mlb_id: 656_427, first_name: "Jack", last_name: "Flaherty" })
    create_team_membership(player: player, team: tigers, starts_on: Date.new(2025, 12, 31))
    payload = {
      "transactions" => [
        transaction(1, "2017-02-16", "ASG", "Assigned", to: cardinals),
        transaction(2, "2017-09-01", "SE", "Selected", to: cardinals),
        transaction(3, "2023-08-01", "TR", "Trade", from: cardinals, to: orioles),
        transaction(4, "2023-11-02", "DFA", "Declared Free Agency", to: orioles),
        transaction(5, "2023-12-20", "SFA", "Signed as Free Agent", to: tigers),
        transaction(6, "2024-07-30", "TR", "Trade", from: tigers, to: dodgers),
        transaction(7, "2024-10-31", "DFA", "Declared Free Agency", to: dodgers),
        transaction(8, "2025-02-07", "SFA", "Signed as Free Agent", to: tigers)
      ]
    }

    result = described_class.call(
      player: player,
      payload: payload,
      source_url: "https://statsapi.mlb.com/example",
      fetched_at: "2026-07-17T20:00:00Z"
    )

    expect(result[:success]).to be(true)
    expect(result.dig(:data, :tenure_count)).to eq(5)
    expect(transaction_memberships(player).map { |membership| [ membership.team.mlb_id, membership.starts_on, membership.ends_on ] }).to eq(
      [
        [ 138, Date.new(2017, 2, 16), Date.new(2023, 7, 31) ],
        [ 110, Date.new(2023, 8, 1), Date.new(2023, 11, 1) ],
        [ 116, Date.new(2023, 12, 20), Date.new(2024, 7, 29) ],
        [ 119, Date.new(2024, 7, 30), Date.new(2024, 10, 30) ],
        [ 116, Date.new(2025, 2, 7), nil ]
      ]
    )
    expect(player.team_memberships.where(source_name: "MLB Stats API").count).to eq(1)

    history = PlayerProfileSnapshotQuery.new(player: player, on: Date.new(2026, 7, 17)).result.fetch(:team_history)
    expect(history.map { |tenure| [ tenure.dig(:team, :mlb_id), tenure[:starts_on], tenure[:ends_on] ] }).to eq(
      [
        [ 116, Date.new(2025, 2, 7), nil ],
        [ 119, Date.new(2024, 7, 30), Date.new(2024, 10, 30) ],
        [ 116, Date.new(2023, 12, 20), Date.new(2024, 7, 29) ],
        [ 110, Date.new(2023, 8, 1), Date.new(2023, 11, 1) ],
        [ 138, Date.new(2017, 2, 16), Date.new(2023, 7, 31) ]
      ]
    )
  end

  it "includes an assigned transaction when it is the first organization event" do
    team = create_team(mlb_id: 138, name: "St. Louis Cardinals", abbreviation: "STL")
    player = create_player(team: team)

    result = described_class.call(
      player: player,
      payload: { "transactions" => [ transaction(1, "2021-07-18", "ASG", "Assigned", to: team) ] }
    )

    expect(result[:success]).to be(true)
    expect(transaction_memberships(player).pluck(:starts_on)).to eq([ Date.new(2021, 7, 18) ])
  end

  it "includes a signed transaction when it is the first organization event" do
    team = create_team(mlb_id: 135, name: "San Diego Padres", abbreviation: "SD")
    player = create_player(team: team)

    result = described_class.call(
      player: player,
      payload: { "transactions" => [ transaction(1, "2021-07-28", "SGN", "Signed", to: team) ] }
    )

    expect(result[:success]).to be(true)
    expect(transaction_memberships(player).pluck(:starts_on)).to eq([ Date.new(2021, 7, 28) ])
  end

  it "replaces only transaction-derived memberships when rerun" do
    team = create_team(mlb_id: 138)
    player = create_player(team: team)
    create_team_membership(
      player: player,
      team: team,
      starts_on: Date.new(2018, 1, 1),
      roster_status: "organization",
      source_name: described_class::SOURCE_NAME
    )
    snapshot = create_team_membership(player: player, team: team, starts_on: Date.new(2025, 12, 31))

    result = described_class.call(
      player: player,
      payload: { "transactions" => [ transaction(1, "2019-01-01", "SE", "Selected", to: team) ] }
    )

    expect(result[:success]).to be(true)
    expect(transaction_memberships(player).pluck(:starts_on)).to eq([ Date.new(2019, 1, 1) ])
    expect(player.team_memberships.exists?(snapshot.id)).to be(true)
  end

  it "rebuilds only the selected season and retains tenures in earlier and later years" do
    first = create_team(mlb_id: 138)
    second = create_team(mlb_id: 110)
    old_destination = create_team(mlb_id: 116)
    new_destination = create_team(mlb_id: 119)
    later = create_team(mlb_id: 147)
    player = create_player(team: later)
    original = [
      transaction(1, "2023-02-01", "SGN", "Signed", to: first),
      transaction(2, "2024-07-01", "TR", "Trade", from: first, to: second),
      transaction(3, "2025-07-01", "TR", "Trade", from: second, to: old_destination),
      transaction(4, "2026-02-01", "TR", "Trade", from: old_destination, to: later)
    ]
    described_class.call(player: player, payload: { "transactions" => original })
    preserved_ids = player.team_memberships.where(source_name: described_class::SOURCE_NAME)
      .where(starts_on: [ Date.new(2023, 2, 1), Date.new(2026, 2, 1) ]).pluck(:id)

    result = described_class.call(player: player,
      payload: { "transactions" => [ transaction(5, "2025-07-01", "TR", "Trade", from: second, to: new_destination) ] },
      season: 2025)

    expect(result[:success]).to be(true)
    expect(result.dig(:data, :transaction_count)).to eq(1)
    expect(transaction_memberships(player).map { |membership| [ membership.team_id, membership.starts_on, membership.ends_on ] }).to eq(
      [
        [ first.id, Date.new(2023, 2, 1), Date.new(2024, 6, 30) ],
        [ second.id, Date.new(2024, 7, 1), Date.new(2025, 6, 30) ],
        [ new_destination.id, Date.new(2025, 7, 1), Date.new(2026, 1, 31) ],
        [ later.id, Date.new(2026, 2, 1), nil ]
      ]
    )
    expect(player.team_memberships.where(id: preserved_ids).count).to eq(2)
  end

  it "leaves stored history untouched when the selected season has no transactions" do
    team = create_team(mlb_id: 138)
    player = create_player(team: team)
    membership = create_team_membership(player: player, team: team,
      starts_on: Date.new(2025, 2, 1), roster_status: "organization",
      source_name: described_class::SOURCE_NAME)

    result = described_class.call(player: player, payload: { "transactions" => [] }, season: 2025)

    expect(result[:success]).to be(true)
    expect(result.dig(:data, :transaction_count)).to eq(0)
    expect(membership.reload.starts_on).to eq(Date.new(2025, 2, 1))
    expect(player.team_memberships.where(source_name: described_class::SOURCE_NAME).pluck(:id)).to eq([ membership.id ])
  end

  def transaction(id, date, type_code, type_desc, from: nil, to: nil)
    {
      "id" => id,
      "date" => date,
      "effectiveDate" => date,
      "typeCode" => type_code,
      "typeDesc" => type_desc,
      "description" => type_desc,
      "fromTeam" => from && { "id" => from.mlb_id, "name" => from.name },
      "toTeam" => to && { "id" => to.mlb_id, "name" => to.name }
    }
  end

  def transaction_memberships(player)
    player.team_memberships.where(source_name: described_class::SOURCE_NAME).includes(:team).order(:starts_on)
  end
end
