require "rails_helper"

RSpec.describe AdminTaskRunner do
  it "runs a schedule synchronization with normalized inputs" do
    result = { success: true, message: "Synchronized 12 MLB games", data: { created_game_count: 12 } }
    allow(MlbScheduleSync).to receive(:call).and_return(result)

    response = described_class.call(
      task_name: "mlb_schedule_sync",
      params: {
        start_date: "2026-07-15",
        end_date: "2026-07-17",
        game_types: "R,F",
        sport_id: "1"
      }
    )

    expect(response).to include(success: true, task: "mlb_schedule_sync")
    expect(MlbScheduleSync).to have_received(:call).with(
      start_date: Date.new(2026, 7, 15),
      end_date: Date.new(2026, 7, 17),
      game_types: "R,F",
      sport_id: 1
    )
  end

  it "runs player profile synchronization with optional filters" do
    allow(MlbPlayerProfilesSync).to receive(:call).and_return(
      success: true,
      message: "Synchronized 2 MLB player profiles",
      data: { profile_count: 2 }
    )

    described_class.call(
      task_name: "mlb_player_profiles_sync",
      params: { only_missing: "false", batch_size: "25", limit: "2", mlb_ids: "700270,669360" }
    )

    expect(MlbPlayerProfilesSync).to have_received(:call).with(
      only_missing: "false",
      batch_size: 25,
      limit: 2,
      mlb_ids: "700270,669360"
    )
  end

  it "runs player organization history synchronization with optional filters" do
    allow(MlbPlayerTeamHistoriesSync).to receive(:call).and_return(
      success: true,
      message: "Synchronized MLB organization history for 1 of 1 players",
      data: { tenure_count: 5 }
    )

    described_class.call(
      task_name: "mlb_player_team_histories_sync",
      params: { limit: "2", mlb_ids: "656427" }
    )

    expect(MlbPlayerTeamHistoriesSync).to have_received(:call).with(limit: 2, mlb_ids: "656427", season: nil)
  end

  it "runs game-detail synchronization for a stored date range" do
    allow(MlbGameDetailsBatchSync).to receive(:call).and_return(
      success: true,
      message: "Synchronized details for 3 of 3 MLB games",
      data: { synchronized_game_count: 3 }
    )

    response = described_class.call(
      task_name: "mlb_game_details_sync",
      params: { start_date: "2026-07-15", end_date: "2026-07-17" }
    )

    expect(response).to include(success: true, task: "mlb_game_details_sync")
    expect(MlbGameDetailsBatchSync).to have_received(:call).with(
      start_date: Date.new(2026, 7, 15),
      end_date: Date.new(2026, 7, 17),
      mlb_game_id: nil
    )
  end

  it "runs game-detail synchronization for one MLB game id" do
    allow(MlbGameDetailsBatchSync).to receive(:call).and_return(
      success: true,
      message: "Synchronized details for 1 of 1 MLB games",
      data: { synchronized_game_count: 1 }
    )

    described_class.call(task_name: "mlb_game_details_sync", params: { mlb_game_id: "823443" })

    expect(MlbGameDetailsBatchSync).to have_received(:call).with(
      start_date: nil,
      end_date: nil,
      mlb_game_id: 823_443
    )
  end

  it "runs roster synchronization for a selected league" do
    allow(Date).to receive(:current).and_return(Date.new(2026, 7, 15))
    allow(MlbRosterBatchSync).to receive(:call).and_return(
      success: true,
      message: "Synchronized 15 MLB team rosters",
      data: { team_count: 15 }
    )

    described_class.call(
      task_name: "mlb_roster_sync",
      params: {
        team_scope: "national",
        season: "2026",
        roster_type: "active",
        as_of: "2026-04-01"
      }
    )

    expect(MlbRosterBatchSync).to have_received(:call).with(
      scope: "national",
      team_mlb_id: nil,
      season: 2026,
      roster_type: "40Man",
      as_of: Date.new(2026, 7, 15)
    )
  end

  it "synchronizes a completed roster season through the end of that year" do
    allow(Date).to receive(:current).and_return(Date.new(2026, 7, 15))
    allow(MlbRosterBatchSync).to receive(:call).and_return(
      success: true,
      message: "Synchronized roster",
      data: { team_count: 1 }
    )

    described_class.call(
      task_name: "mlb_roster_sync",
      params: { team_scope: "team", team_mlb_id: "116", season: "2025" }
    )

    expect(MlbRosterBatchSync).to have_received(:call).with(
      scope: "team",
      team_mlb_id: 116,
      season: 2025,
      roster_type: "40Man",
      as_of: Date.new(2025, 12, 31)
    )
  end

  it "rejects future roster seasons" do
    allow(Date).to receive(:current).and_return(Date.new(2026, 7, 15))
    allow(MlbRosterBatchSync).to receive(:call)

    response = described_class.call(
      task_name: "mlb_roster_sync",
      params: { team_scope: "team", team_mlb_id: "116", season: "2027" }
    )

    expect(response).to include(success: false, message: "Season cannot be in the future")
    expect(MlbRosterBatchSync).not_to have_received(:call)
  end

  it "captures dated Active and 40-man roster snapshots" do
    allow(MlbRosterSnapshotSync).to receive(:call).and_return(
      success: true,
      message: "Stored snapshots",
      data: { player_counts: { "active" => 26, "40Man" => 40 } }
    )

    response = described_class.call(
      task_name: "mlb_roster_snapshots_sync",
      params: { team_mlb_id: "116", snapshot_on: "2026-07-15" }
    )

    expect(response).to include(success: true, task: "mlb_roster_snapshots_sync")
    expect(MlbRosterSnapshotSync).to have_received(:call).with(
      team_mlb_id: 116,
      snapshot_on: Date.new(2026, 7, 15)
    )
  end

  it "rejects invalid or reversed schedule dates without calling the synchronizer" do
    allow(MlbScheduleSync).to receive(:call)

    response = described_class.call(
      task_name: "mlb_schedule_sync",
      params: { start_date: "2026-07-16", end_date: "2026-07-15" }
    )

    expect(response).to include(success: false, message: "End date must be on or after start date")
    expect(MlbScheduleSync).not_to have_received(:call)
  end

  it "returns a not-found result for tasks outside the allowlist" do
    response = described_class.call(task_name: "db_drop", params: {})

    expect(response).to include(success: false, error: :not_found, task: "db_drop")
  end

  it "runs an incremental daily analytics refresh" do
    allow(DailyAnalyticsRefresh).to receive(:call).and_return(success: true, message: "Refreshed", data: {})

    response = described_class.call(
      task_name: "daily_analytics_refresh",
      params: { start_date: "2026-07-15", end_date: "2026-07-16", calculation_version: "2.0.0" }
    )

    expect(response).to include(success: true, task: "daily_analytics_refresh")
    expect(DailyAnalyticsRefresh).to have_received(:call).with(
      start_date: Date.new(2026, 7, 15),
      end_date: Date.new(2026, 7, 16),
      calculation_version: "2.0.0"
    )
  end

  it "runs a contextual benchmark refresh" do
    allow(ContextualBenchmarkRefresh).to receive(:call).and_return(success: true, message: "Refreshed", data: {})

    response = described_class.call(
      task_name: "contextual_benchmarks_refresh",
      params: { start_date: "2026-04-01", end_date: "2026-07-15", calculation_version: "2.0.0" }
    )

    expect(response).to include(success: true, task: "contextual_benchmarks_refresh")
    expect(ContextualBenchmarkRefresh).to have_received(:call).with(
      start_date: Date.new(2026, 4, 1),
      end_date: Date.new(2026, 7, 15),
      calculation_version: "2.0.0"
    )
  end
end
