require "rails_helper"

RSpec.describe "Synchronization task launchers" do
  it "launches game-detail synchronization from its normalized estimate" do
    estimate = {
      task_parameters: { "start_date" => "2026-07-15", "end_date" => "2026-07-16" },
      game_count: 2,
      estimated_seconds: 100
    }
    allow(MlbGameDetailsTaskEstimate).to receive(:call).and_return(estimate)
    allow(MlbGameDetailsSyncJob).to receive(:perform_later).and_return(double("job"))

    run = MlbGameDetailsTaskLauncher.call(start_date: "2026-07-15", end_date: "2026-07-16")

    expect(run).to have_attributes(total_items: 2, estimated_duration_seconds: 100)
    expect(MlbGameDetailsTaskEstimate).to have_received(:call).with(
      start_date: "2026-07-15",
      end_date: "2026-07-16",
      mlb_game_id: nil
    )
  end

  it "launches pitch-data synchronization from its normalized estimate" do
    estimate = {
      task_parameters: {
        "start_date" => "2026-07-15",
        "end_date" => "2026-07-16",
        "game_types" => "R",
        "chunk_days" => 2,
        "replace_existing" => false
      },
      game_count: 3,
      estimated_seconds: 180
    }
    allow(PitchDataSyncTaskEstimate).to receive(:call).and_return(estimate)
    allow(PitchDataSyncJob).to receive(:perform_later).and_return(double("job"))

    run = PitchDataSyncTaskLauncher.call(
      start_date: "2026-07-15",
      end_date: "2026-07-16",
      game_types: "R",
      chunk_days: 2
    )

    expect(run).to have_attributes(total_items: 3, estimated_duration_seconds: 180)
    expect(PitchDataSyncTaskEstimate).to have_received(:call).with(
      start_date: "2026-07-15",
      end_date: "2026-07-16",
      game_types: "R",
      chunk_days: 2,
      replace_existing: false
    )
  end

  it "launches roster synchronization using the estimate's team count" do
    estimate = {
      task_parameters: { "team_scope" => "national", "team_mlb_id" => nil, "season" => 2026 },
      team_count: 15,
      estimated_seconds: 120
    }
    allow(MlbRosterSyncTaskEstimate).to receive(:call).and_return(estimate)
    allow(MlbRosterBatchSyncJob).to receive(:perform_later).and_return(double("job"))

    run = MlbRosterSyncTaskLauncher.call(team_scope: "national", season: 2026)

    expect(run).to have_attributes(total_items: 15, estimated_duration_seconds: 120)
    expect(MlbRosterSyncTaskEstimate).to have_received(:call).with(
      team_scope: "national",
      team_mlb_id: nil,
      season: 2026
    )
  end
end
