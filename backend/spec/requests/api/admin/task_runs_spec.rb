require "rails_helper"

RSpec.describe "Api::Admin::TaskRuns", type: :request do
  include ActiveJob::TestHelper
  around { |example| with_admin_api_token("test-admin-token", &example) }

  it "estimates from the exact stored-game count before starting a task" do
    create_game(mlb_id: 810_001, official_date: Date.new(2026, 7, 15))
    create_game(mlb_id: 810_002, official_date: Date.new(2026, 7, 15))

    get estimate_api_admin_task_runs_path, params: { start_date: "2026-07-15", end_date: "2026-07-15" }, headers: admin_headers

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("data")).to include(
      "game_count" => 2,
      "estimated_seconds" => 100,
      "estimate_source" => "conservative_default"
    )
  end

  it "enqueues a tracked game-detail synchronization with a stored game count" do
    create_game(mlb_id: 810_001, official_date: Date.new(2026, 7, 15))
    create_game(mlb_id: 810_002, official_date: Date.new(2026, 7, 15))

    expect do
      post api_admin_task_runs_path, params: {
        task_name: "mlb_game_details_sync",
        start_date: "2026-07-15",
        end_date: "2026-07-15"
      }, headers: admin_headers
    end.to have_enqueued_job(MlbGameDetailsSyncJob)

    expect(response).to have_http_status(:accepted)
    expect(json_body.fetch("data")).to include(
      "task_name" => "mlb_game_details_sync",
      "status" => "queued",
      "total_items" => 2,
      "processed_items" => 0,
      "progress_percentage" => 0.0,
      "estimated_remaining_seconds" => 100
    )
  end

  it "enqueues remaining admin operations with initiator attribution" do
    expect do
      post api_admin_task_runs_path, params: {
        task_name: "player_positions_backfill"
      }, headers: admin_headers
    end.to have_enqueued_job(AdminTaskJob)

    expect(response).to have_http_status(:accepted)
    expect(json_body.fetch("data")).to include(
      "task_name" => "player_positions_backfill",
      "status" => "queued",
      "total_items" => 1,
      "progress_percentage" => 0.0
    )
    expect(json_body.dig("data", "initiated_by")).to include(
      "role" => "admin"
    )
  end

  it "queues transaction history synchronization with the selected player count" do
    selected = create_player(attributes: { mlb_id: 656_427 })
    create_player(attributes: { mlb_id: 669_360 })
    create_player(attributes: { mlb_id: 700_001 })

    expect do
      post api_admin_task_runs_path, params: {
        task_name: "mlb_player_team_histories_sync", mlb_ids: "#{selected.mlb_id},669360", limit: 1, season: 2025
      }, headers: admin_headers
    end.to have_enqueued_job(MlbPlayerTeamHistoriesSyncJob)

    expect(response).to have_http_status(:accepted)
    expect(json_body.fetch("data")).to include(
      "task_name" => "mlb_player_team_histories_sync",
      "task_parameters" => include("season" => "2025"),
      "total_items" => 1,
      "completed_items" => 0,
      "failed_items" => 0
    )
  end

  it "rejects a transaction history season in the future" do
    post api_admin_task_runs_path, params: {
      task_name: "mlb_player_team_histories_sync",
      season: ApplicationCalendar.current_date.year + 1
    }, headers: admin_headers

    expect(response).to have_http_status(:unprocessable_content)
    expect(json_body.fetch("message")).to include("Season must be between 1900")
    expect(AdminTaskRun.where(task_name: "mlb_player_team_histories_sync")).to be_empty
  end

  it "estimates and enqueues a tracked roster synchronization by team count" do
    get estimate_api_admin_task_runs_path, params: {
      task_name: "mlb_roster_sync",
      team_scope: "national",
      season: Date.current.year
    }, headers: admin_headers

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("data")).to include(
      "team_count" => 15,
      "estimated_seconds" => 120,
      "estimate_source" => "conservative_default"
    )

    expect do
      post api_admin_task_runs_path, params: {
        task_name: "mlb_roster_sync",
        team_scope: "national",
        season: Date.current.year
      }, headers: admin_headers
    end.to have_enqueued_job(MlbRosterBatchSyncJob)

    expect(response).to have_http_status(:accepted)
    expect(json_body.fetch("data")).to include(
      "task_name" => "mlb_roster_sync",
      "status" => "queued",
      "total_items" => 15,
      "processed_items" => 0,
      "progress_percentage" => 0.0,
      "estimated_remaining_seconds" => 120
    )
  end

  it "returns active runs for page-reload recovery and accepts cancellation" do
    completed = AdminTaskRun.create!(task_name: "mlb_game_details_sync", status: "completed", total_items: 1, completed_items: 1)
    active = AdminTaskRun.create!(task_name: "mlb_game_details_sync", status: "running", total_items: 10, completed_items: 4)

    get api_admin_task_runs_path, params: { task_name: "mlb_game_details_sync", active: true }, headers: admin_headers

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("data").pluck("id")).to eq([ active.id ])
    expect(json_body.fetch("data").pluck("id")).not_to include(completed.id)

    post cancel_api_admin_task_run_path(active), headers: admin_headers

    expect(response).to have_http_status(:accepted)
    expect(json_body.fetch("data")).to include("id" => active.id, "cancel_requested" => true, "status" => "running")
  end

  it "shows current progress and rejects invalid ranges" do
    run = AdminTaskRun.create!(
      task_name: "mlb_game_details_sync",
      status: "running",
      total_items: 10,
      completed_items: 4,
      current_item_mlb_id: 810_005,
      current_item_label: "DET at CLE — July 15, 2026",
      started_at: 1.minute.ago
    )

    get api_admin_task_run_path(run), headers: admin_headers
    expect(json_body.fetch("data")).to include(
      "progress_percentage" => 40.0,
      "current_item_mlb_id" => 810_005,
      "current_item_label" => "DET at CLE — July 15, 2026"
    )

      post api_admin_task_runs_path, params: {
      task_name: "mlb_game_details_sync",
      start_date: "2026-07-16",
      end_date: "2026-07-15"
      }, headers: admin_headers
    expect(response).to have_http_status(:unprocessable_content)
    expect(json_body.fetch("message")).to eq("End date must be on or after start date")
  end

  it "marks orphaned running game-detail tasks as failed when worker execution has crashed" do
    run = AdminTaskRun.create!(
      task_name: "mlb_game_details_sync",
      status: "running",
      total_items: 91,
      completed_items: 36,
      failed_items: 0,
      result_data: { "active_execution_job_id" => "stale-exec-id" },
      last_heartbeat_at: 5.minutes.ago,
      started_at: 10.minutes.ago
    )

    queue_job = instance_double("SolidQueue::Job", id: 123, finished_at: nil)
    failed_execution = instance_double("SolidQueue::FailedExecution", message: "Process pid=1169 exited unexpectedly. Exited with status 1.")
    failed_scope = instance_double("ActiveRecord::Relation")

    allow(SolidQueue::Job).to receive(:find_by).with(active_job_id: "stale-exec-id").and_return(queue_job)
    allow(SolidQueue::ClaimedExecution).to receive(:exists?).with(job_id: 123).and_return(false)
    allow(SolidQueue::FailedExecution).to receive(:where).with(job_id: 123).and_return(failed_scope)
    allow(failed_scope).to receive(:order).with(created_at: :desc).and_return(failed_scope)
    allow(failed_scope).to receive(:first).and_return(failed_execution)

    get api_admin_task_run_path(run), headers: admin_headers

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", "status")).to eq("failed")
    expect(json_body.dig("data", "error_message")).to include("Process pid=1169 exited unexpectedly")
    expect(json_body.dig("data", "result_data", "active_execution_job_id")).to be_nil
  end

  it "marks orphaned running game-detail tasks as failed immediately when queue failure exists" do
    run = AdminTaskRun.create!(
      task_name: "mlb_game_details_sync",
      status: "running",
      total_items: 59,
      completed_items: 44,
      failed_items: 0,
      result_data: { "active_execution_job_id" => "fresh-exec-id" },
      last_heartbeat_at: 5.seconds.ago,
      started_at: 2.minutes.ago
    )

    queue_job = instance_double("SolidQueue::Job", id: 456, finished_at: nil)
    failed_execution = instance_double("SolidQueue::FailedExecution", message: "Process pid=19201 exited unexpectedly. Received unhandled signal 9.")
    failed_scope = instance_double("ActiveRecord::Relation")

    allow(SolidQueue::Job).to receive(:find_by).with(active_job_id: "fresh-exec-id").and_return(queue_job)
    allow(SolidQueue::ClaimedExecution).to receive(:exists?).with(job_id: 456).and_return(false)
    allow(SolidQueue::FailedExecution).to receive(:where).with(job_id: 456).and_return(failed_scope)
    allow(failed_scope).to receive(:order).with(created_at: :desc).and_return(failed_scope)
    allow(failed_scope).to receive(:first).and_return(failed_execution)

    get api_admin_task_run_path(run), headers: admin_headers

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", "status")).to eq("failed")
    expect(json_body.dig("data", "error_message")).to include("Received unhandled signal 9")
    expect(json_body.dig("data", "result_data", "active_execution_job_id")).to be_nil
  end

  it "marks legacy pitch-data tasks as failed when their worker process died" do
    run = AdminTaskRun.create!(
      task_name: "pitch_data_sync",
      status: "running",
      total_items: 1,
      result_data: {},
      last_heartbeat_at: 5.minutes.ago,
      started_at: 10.minutes.ago
    )

    queue_job = instance_double(
      "SolidQueue::Job",
      id: 789,
      finished_at: nil,
      arguments: { "arguments" => [ run.id ] }
    )
    jobs_scope = instance_double("ActiveRecord::Relation")
    failed_execution = instance_double("SolidQueue::FailedExecution", message: "Process was found dead and pruned")
    failed_scope = instance_double("ActiveRecord::Relation")

    allow(SolidQueue::Job).to receive(:where).with(class_name: "PitchDataSyncJob").and_return(jobs_scope)
    allow(jobs_scope).to receive(:order).with(created_at: :desc).and_return([ queue_job ])
    allow(SolidQueue::ClaimedExecution).to receive(:exists?).with(job_id: 789).and_return(false)
    allow(SolidQueue::FailedExecution).to receive(:where).with(job_id: 789).and_return(failed_scope)
    allow(failed_scope).to receive(:order).with(created_at: :desc).and_return(failed_scope)
    allow(failed_scope).to receive(:first).and_return(failed_execution)

    get api_admin_task_run_path(run), headers: admin_headers

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", "status")).to eq("failed")
    expect(json_body.dig("data", "error_message")).to include("Process was found dead and pruned")
  end

  it "prevents concurrent game-detail synchronizations" do
    AdminTaskRun.create!(task_name: "mlb_game_details_sync", status: "running")

      post api_admin_task_runs_path, params: {
      task_name: "mlb_game_details_sync",
      start_date: "2026-07-15",
      end_date: "2026-07-15"
      }, headers: admin_headers

    expect(response).to have_http_status(:unprocessable_content)
    expect(json_body.fetch("message")).to eq("A game detail synchronization is already queued or running")
  end
end
