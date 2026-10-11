class MlbRosterSyncTaskLauncher
  TASK_NAME = MlbRosterSyncTaskEstimate::TASK_NAME
  MESSAGES = {
    already_active: "A roster synchronization is already queued or running",
    enqueue_failure: "Roster synchronization could not be enqueued"
  }.freeze

  def self.call(team_scope:, team_mlb_id: nil, season: Date.current.year, initiated_by: nil)
    estimate = MlbRosterSyncTaskEstimate.call(team_scope:, team_mlb_id:, season:)
    AdminTaskLauncher.call(
      task_name: TASK_NAME,
      estimate:,
      job_class: MlbRosterBatchSyncJob,
      total_count_key: :team_count,
      messages: MESSAGES,
      initiated_by:
    )
  end
end
