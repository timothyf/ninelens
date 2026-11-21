class MlbPlayerTeamHistoriesSyncProgressTracker
  def initialize(task_run) = @task_run = task_run

  def start!(total:)
    task_run.update!(
      status: "running", total_items: total, completed_items: 0, failed_items: 0,
      current_item_mlb_id: nil, current_item_label: nil, error_message: nil,
      remaining_time_anchor_at: nil, started_at: task_run.started_at || Time.current,
      finished_at: nil, last_heartbeat_at: Time.current
    )
  end

  def player_started!(player)
    task_run.update!(
      current_item_mlb_id: player.mlb_id,
      current_item_label: "#{player.full_name} · MLB ##{player.mlb_id}",
      last_heartbeat_at: Time.current
    )
  end

  def player_finished!(success:)
    task_run.reload
    task_run.update!(
      completed_items: task_run.completed_items + (success ? 1 : 0),
      failed_items: task_run.failed_items + (success ? 0 : 1),
      remaining_time_anchor_at: Time.current,
      last_heartbeat_at: Time.current
    )
  end

  def cancel_requested? = task_run.reload.cancel_requested?
  def complete!(result) = finish!("completed", result)
  def cancel!(result) = finish!("cancelled", result)
  def fail!(message, result: nil) = finish!("failed", result || { success: false, message: message, data: {} }, message)

  private

  attr_reader :task_run

  def finish!(status, result, error_message = nil)
    data = result.deep_stringify_keys
    data["progress_unit"] = "players"
    task_run.update!(
      status: status, result_data: data, error_message: error_message,
      current_item_mlb_id: nil, current_item_label: nil,
      finished_at: Time.current, last_heartbeat_at: Time.current
    )
  end
end
