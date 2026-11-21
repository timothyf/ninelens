class MlbPlayerTeamHistoriesSyncJob < ApplicationJob
  queue_as :default

  def perform(task_run_id)
    run = AdminTaskRun.find(task_run_id)
    return if run.terminal?

    run.update!(
      result_data: run.result_data.to_h.merge("active_execution_job_id" => job_id),
      started_at: run.started_at || Time.current,
      last_heartbeat_at: Time.current
    )
    tracker = MlbPlayerTeamHistoriesSyncProgressTracker.new(run)
    parameters = run.task_parameters.symbolize_keys
    result = MlbPlayerTeamHistoriesSync.call(
      limit: parameters[:limit], mlb_ids: parameters[:mlb_ids], season: parameters[:season], progress_tracker: tracker
    )

    if result.dig(:data, :cancelled)
      tracker.cancel!(result)
    elsif result[:success]
      tracker.complete!(result)
    else
      tracker.fail!(result[:message], result: result)
    end
    result
  rescue StandardError => error
    tracker&.fail!(error.message)
    raise
  end
end
