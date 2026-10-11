require "rails_helper"

RSpec.describe AdminTaskLauncher do
  let(:job_class) { class_double(MlbGameDetailsSyncJob) }
  let(:messages) do
    {
      already_active: "A synchronization is already queued or running",
      enqueue_failure: "Synchronization could not be enqueued"
    }
  end
  let(:estimate) do
    {
      task_parameters: { "start_date" => "2026-07-15", "end_date" => "2026-07-16" },
      game_count: 12,
      estimated_seconds: 600
    }
  end

  def launch
    described_class.call(
      task_name: "example_sync",
      estimate:,
      job_class:,
      total_count_key: :game_count,
      messages:
    )
  end

  it "creates a run from a normalized estimate and enqueues the configured job" do
    allow(job_class).to receive(:perform_later).and_return(double("job"))

    run = launch

    expect(run).to have_attributes(
      task_name: "example_sync",
      task_parameters: estimate.fetch(:task_parameters),
      total_items: 12,
      estimated_duration_seconds: 600,
      status: "queued"
    )
    expect(job_class).to have_received(:perform_later).with(run.id)
  end

  it "uses the configured message when an active run already exists" do
    AdminTaskRun.create!(task_name: "example_sync", status: "running")

    expect { launch }.to raise_error(ArgumentError, messages.fetch(:already_active))
  end

  it "converts a unique-index race into the same active-run error" do
    allow(AdminTaskRun).to receive(:create!).and_raise(ActiveRecord::RecordNotUnique)

    expect { launch }.to raise_error(ArgumentError, messages.fetch(:already_active))
  end

  it "marks the run failed when the adapter returns no enqueued job" do
    allow(job_class).to receive(:perform_later).and_return(nil)

    expect { launch }.to raise_error(AdminTaskLauncher::EnqueueFailure, messages.fetch(:enqueue_failure))

    expect(AdminTaskRun.last).to have_attributes(
      status: "failed",
      error_message: messages.fetch(:enqueue_failure),
      failed_items: 0
    )
    expect(AdminTaskRun.last.finished_at).to be_present
  end

  it "marks the run failed when the queue adapter raises an enqueue error" do
    allow(job_class).to receive(:perform_later).and_raise(ActiveJob::EnqueueError, "Queue unavailable")

    expect { launch }.to raise_error(ActiveJob::EnqueueError, "Queue unavailable")

    expect(AdminTaskRun.last).to have_attributes(status: "failed", error_message: "Queue unavailable")
  end

  it "preserves the generic admin task launcher API" do
    allow(AdminTaskJob).to receive(:perform_later).and_return(double("job"))

    run = described_class.call(
      task_name: "player_positions_backfill",
      params: { "limit" => "10" }
    )

    expect(run).to have_attributes(
      task_name: "player_positions_backfill",
      task_parameters: { "limit" => "10" },
      total_items: 1,
      current_item_label: "Player position backfill"
    )
  end
end
