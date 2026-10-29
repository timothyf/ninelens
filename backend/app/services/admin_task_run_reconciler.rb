class AdminTaskRunReconciler
  def self.call(task_run)
    new(task_run).call
  end

  def initialize(task_run)
    @task_run = task_run
  end

  def call
    return task_run unless task_run.active?
    return task_run unless tracked_task_name?

    execution_job_id = task_run.result_data.to_h["active_execution_job_id"]
    stale_heartbeat = task_run.last_heartbeat_at.blank? || task_run.last_heartbeat_at < orphaned_task_heartbeat_seconds.seconds.ago
    queue_job = execution_job_id.present? ? SolidQueue::Job.find_by(active_job_id: execution_job_id) : legacy_queue_job_for(stale_heartbeat: stale_heartbeat)
    return task_run unless queue_job
    return task_run if SolidQueue::ClaimedExecution.exists?(job_id: queue_job.id)

    failed_execution = SolidQueue::FailedExecution.where(job_id: queue_job.id).order(created_at: :desc).first
    return task_run if failed_execution.blank? && !stale_heartbeat
    return task_run if failed_execution.blank? && queue_job.finished_at.present?

    failure_message = failed_execution&.message.presence || "Background worker exited before this task could finish"
    task_run.with_lock do
      task_run.reload
      if task_run.active?
        result_data = task_run.result_data.to_h.deep_dup
        result_data.delete("active_execution_job_id")
        errors = Array(result_data["errors"])
        errors << { "mlb_id" => nil, "message" => failure_message, "errors" => ["orphaned_execution"] }
        result_data["errors"] = errors
        task_run.update!(
          status: "failed",
          error_message: failure_message,
          finished_at: Time.current,
          result_data: result_data,
          last_heartbeat_at: Time.current
        )
      end
    end

    task_run
  end

  private

  attr_reader :task_run

  def tracked_task_name?
    task_run.task_name.in?(
      AdminTaskRunner::TASKS.keys +
        AdminImportTaskLauncher::TASK_NAMES +
        [
          MlbGameDetailsTaskLauncher::TASK_NAME,
          PitchDataSyncTaskLauncher::TASK_NAME,
          MlbRosterSyncTaskLauncher::TASK_NAME
        ]
    )
  end

  def legacy_queue_job_for(stale_heartbeat:)
    return unless stale_heartbeat

    job_class = {
      MlbGameDetailsTaskLauncher::TASK_NAME => "MlbGameDetailsSyncJob",
      PitchDataSyncTaskLauncher::TASK_NAME => "PitchDataSyncJob",
      MlbRosterSyncTaskLauncher::TASK_NAME => "MlbRosterBatchSyncJob"
    }.fetch(task_run.task_name) do
      task_run.task_name.in?(AdminImportTaskLauncher::TASK_NAMES) ? "AdminImportJob" : "AdminTaskJob"
    end

    SolidQueue::Job.where(class_name: job_class).order(created_at: :desc).find do |job|
      Array(job.arguments.to_h["arguments"]).first.to_i == task_run.id
    end
  end

  def orphaned_task_heartbeat_seconds
    NineLensConfig.fetch(:operations, :game_details, :orphaned_task_heartbeat_seconds).to_i
  end
end
