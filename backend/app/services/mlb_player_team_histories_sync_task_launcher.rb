class MlbPlayerTeamHistoriesSyncTaskLauncher
  TASK_NAME = "mlb_player_team_histories_sync"
  MESSAGES = {
    already_active: "MLB transaction history synchronization is already queued or running",
    enqueue_failure: "MLB transaction history synchronization could not be enqueued"
  }.freeze

  def self.call(limit: nil, mlb_ids: nil, season: nil, initiated_by: nil)
    AdminTaskLauncher.call(
      task_name: TASK_NAME,
      estimate: {
        task_parameters: { limit: limit, mlb_ids: mlb_ids, season: season },
        player_count: MlbPlayerTeamHistoriesSync.selected_player_count(limit: limit, mlb_ids: mlb_ids, season: season)
      },
      job_class: MlbPlayerTeamHistoriesSyncJob,
      total_count_key: :player_count,
      messages: MESSAGES,
      initiated_by: initiated_by
    )
  end
end
