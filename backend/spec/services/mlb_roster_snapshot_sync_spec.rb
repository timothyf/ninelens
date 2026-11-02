require "rails_helper"

RSpec.describe MlbRosterSnapshotSync do
  let(:team) { create_team(mlb_id: 116, name: "Detroit Tigers", abbreviation: "DET") }
  let(:existing_player) do
    create_player(
      team: team,
      attributes: { mlb_id: 592_450, first_name: "Aaron", last_name: "Judge" }
    )
  end
  let(:snapshot_on) { Date.new(2026, 7, 15) }

  before do
    team
    existing_player
    allow(Date).to receive(:current).and_return(snapshot_on)
    allow(MlbRosterDownloader).to receive(:call) do |roster_type:, **|
      payload = roster_type == "active" ? active_payload : forty_man_payload
      {
        success: true,
        message: "Downloaded roster",
        data: {
          payload: payload,
          source_url: "https://statsapi.mlb.com/teams/116/roster?rosterType=#{roster_type}",
          fetched_at: "2026-07-15T12:00:00Z"
        }
      }
    end
  end

  it "stores independent Active and 40-man snapshots without changing memberships" do
    result = described_class.call(team_mlb_id: 116, snapshot_on: snapshot_on)

    expect(result).to include(success: true)
    expect(result.dig(:data, :player_counts)).to eq("40Man" => 2, "active" => 1)
    expect(team.roster_snapshots.pluck(:roster_type)).to contain_exactly("40Man", "active")
    expect(TeamMembership.count).to eq(0)

    active_snapshot = team.roster_snapshots.find_by!(roster_type: "active")
    expect(active_snapshot.raw_data).to eq(active_payload)
    active_entry = active_snapshot.roster_snapshot_players.first
    expect(active_entry).to have_attributes(
      player_id: existing_player.id,
      mlb_id: 592_450,
      full_name: "Aaron Judge",
      status_description: "Active"
    )

    forty_man_entry = team.roster_snapshots
      .find_by!(roster_type: "40Man")
      .roster_snapshot_players
      .find_by!(mlb_id: 700_001)
    expect(forty_man_entry.player_id).to be_nil
    expect(forty_man_entry.position_code).to eq("P")
  end

  it "replaces entries in place when the same snapshot is retrieved again" do
    2.times { described_class.call(team_mlb_id: 116, snapshot_on: snapshot_on) }

    expect(RosterSnapshot.count).to eq(2)
    expect(RosterSnapshotPlayer.count).to eq(3)
  end

  it "does not persist either snapshot when one download fails" do
    allow(MlbRosterDownloader).to receive(:call) do |roster_type:, **|
      if roster_type == "active"
        { success: false, message: "HTTP 503", data: {} }
      else
        { success: true, data: { payload: forty_man_payload, source_url: "url", fetched_at: Time.current } }
      end
    end

    result = described_class.call(team_mlb_id: 116, snapshot_on: snapshot_on)

    expect(result).to include(success: false, message: "HTTP 503")
    expect(RosterSnapshot.count).to eq(0)
  end

  it "rejects future dates" do
    result = described_class.call(team_mlb_id: 116, snapshot_on: snapshot_on + 1.day)

    expect(result).to include(success: false, message: "Snapshot date cannot be in the future")
    expect(MlbRosterDownloader).not_to have_received(:call)
  end

  def active_payload
    {
      "roster" => [
        roster_entry(592_450, "Aaron Judge", status: "Active", status_code: "A", position: "RF")
      ]
    }
  end

  def forty_man_payload
    {
      "roster" => [
        roster_entry(592_450, "Aaron Judge", status: "Active", status_code: "A", position: "RF"),
        roster_entry(700_001, "Test Pitcher", status: "Minors", status_code: "MIN", position: "P")
      ]
    }
  end

  def roster_entry(mlb_id, full_name, status:, status_code:, position:)
    first_name, last_name = full_name.split(" ", 2)
    {
      "person" => {
        "id" => mlb_id,
        "fullName" => full_name,
        "firstName" => first_name,
        "lastName" => last_name
      },
      "jerseyNumber" => "99",
      "position" => { "abbreviation" => position, "name" => position == "P" ? "Pitcher" : "Outfielder" },
      "status" => { "code" => status_code, "description" => status }
    }
  end
end
