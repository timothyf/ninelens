class PitchDataSyncTaskLauncher
  TASK_NAME = PitchDataSyncTaskEstimate::TASK_NAME
  MESSAGES = {
    already_active: "A Statcast pitch data synchronization is already queued or running",
    enqueue_failure: "Statcast pitch data synchronization could not be enqueued"
  }.freeze

  def self.call(start_date:, end_date:, game_types:, chunk_days:, replace_existing: false, initiated_by: nil)
    new(start_date: start_date, end_date: end_date, game_types: game_types, chunk_days: chunk_days, replace_existing: replace_existing, initiated_by:).call
  end

  def initialize(start_date:, end_date:, game_types:, chunk_days:, replace_existing: false, initiated_by: nil)
    @start_date = start_date
    @end_date = end_date
    @game_types = game_types
    @chunk_days = chunk_days
    @replace_existing = replace_existing
    @initiated_by = initiated_by
  end

  def call
    estimate = PitchDataSyncTaskEstimate.call(start_date: @start_date, end_date: @end_date, game_types: @game_types, chunk_days: @chunk_days, replace_existing: @replace_existing)
    AdminTaskLauncher.call(
      task_name: TASK_NAME,
      estimate:,
      job_class: PitchDataSyncJob,
      total_count_key: :game_count,
      messages: MESSAGES,
      initiated_by: @initiated_by
    )
  end
end
