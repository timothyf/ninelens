require "rails_helper"

RSpec.describe ScheduledGameDetailsSyncJob, type: :job do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  around do |example|
    travel_to(Time.utc(2026, 7, 16, 2, 0)) { example.run }
  end

  it "starts the existing tracked sync for the current Detroit date" do
    create_game(mlb_id: 810_001, official_date: Date.new(2026, 7, 15))

    expect { described_class.perform_now }.to have_enqueued_job(MlbGameDetailsSyncJob)

    run = AdminTaskRun.find_by!(task_name: MlbGameDetailsTaskLauncher::TASK_NAME)
    expect(run.task_parameters).to include("start_date" => "2026-07-15", "end_date" => "2026-07-15")
    expect(run.initiated_by).to be_nil
    expect(AutomationSetting.game_details_sync.last_started_at).to eq(Time.current)
  end

  it "waits for the saved interval before starting another run" do
    create_game(mlb_id: 810_005, official_date: Date.new(2026, 7, 15))
    setting = AutomationSetting.game_details_sync
    setting.update!(interval_minutes: 30, last_started_at: 20.minutes.ago)

    expect { described_class.perform_now }.not_to change(AdminTaskRun, :count)

    setting.update!(interval_minutes: 5)
    expect { described_class.perform_now }.to have_enqueued_job(MlbGameDetailsSyncJob)
  end

  it "runs on the due minute even when the previous launch took part of a second" do
    create_game(mlb_id: 810_006, official_date: Date.new(2026, 7, 15))
    AutomationSetting.game_details_sync.update!(
      interval_minutes: 10,
      last_started_at: 10.minutes.ago + 0.75
    )

    expect { described_class.perform_now }.to have_enqueued_job(MlbGameDetailsSyncJob)
  end

  it "does not start a run when disabled" do
    AutomationSetting.game_details_sync.update!(enabled: false)
    create_game(mlb_id: 810_002, official_date: Date.new(2026, 7, 15))

    expect { described_class.perform_now }.not_to change(AdminTaskRun, :count)
  end

  it "does not overlap an active sync" do
    create_game(mlb_id: 810_003, official_date: Date.new(2026, 7, 15))
    AdminTaskRun.create!(task_name: MlbGameDetailsTaskLauncher::TASK_NAME, status: "running")

    expect { described_class.perform_now }.not_to change(AdminTaskRun, :count)
  end

  it "recovers a failed worker before starting the next scheduled sync" do
    create_game(mlb_id: 810_004, official_date: Date.new(2026, 7, 15))
    stale_run = AdminTaskRun.create!(
      task_name: MlbGameDetailsTaskLauncher::TASK_NAME,
      status: "running",
      result_data: { "active_execution_job_id" => "crashed-job" },
      last_heartbeat_at: 5.minutes.ago
    )
    queue_job = instance_double("SolidQueue::Job", id: 123, finished_at: nil)
    failed_execution = instance_double("SolidQueue::FailedExecution", message: "Worker exited")
    failed_scope = instance_double("ActiveRecord::Relation")
    allow(SolidQueue::Job).to receive(:find_by).with(active_job_id: "crashed-job").and_return(queue_job)
    allow(SolidQueue::ClaimedExecution).to receive(:exists?).with(job_id: 123).and_return(false)
    allow(SolidQueue::FailedExecution).to receive(:where).with(job_id: 123).and_return(failed_scope)
    allow(failed_scope).to receive(:order).with(created_at: :desc).and_return(failed_scope)
    allow(failed_scope).to receive(:first).and_return(failed_execution)

    expect { described_class.perform_now }.to have_enqueued_job(MlbGameDetailsSyncJob)
    expect(stale_run.reload.status).to eq("failed")
    expect(AdminTaskRun.active.where(task_name: MlbGameDetailsTaskLauncher::TASK_NAME).count).to eq(1)
  end

  it "does not create an empty run when no games are stored for the date" do
    expect { described_class.perform_now }.not_to change(AdminTaskRun, :count)
  end
end
