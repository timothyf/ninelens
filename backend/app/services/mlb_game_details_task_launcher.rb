class MlbGameDetailsTaskLauncher
  TASK_NAME = MlbGameDetailsTaskEstimate::TASK_NAME
  MESSAGES = {
    already_active: "A game detail synchronization is already queued or running",
    enqueue_failure: "Game detail synchronization could not be enqueued"
  }.freeze

  def self.call(start_date: nil, end_date: nil, mlb_game_id: nil, initiated_by: nil)
    new(start_date: start_date, end_date: end_date, mlb_game_id: mlb_game_id, initiated_by:).call
  end

  def initialize(start_date: nil, end_date: nil, mlb_game_id: nil, initiated_by: nil)
    @start_date_input = start_date
    @end_date_input = end_date
    @mlb_game_id_input = mlb_game_id
    @initiated_by = initiated_by
  end

  def call
    estimate = MlbGameDetailsTaskEstimate.call(
      start_date: start_date_input,
      end_date: end_date_input,
      mlb_game_id: mlb_game_id_input
    )
    AdminTaskLauncher.call(
      task_name: TASK_NAME,
      estimate:,
      job_class: MlbGameDetailsSyncJob,
      total_count_key: :game_count,
      messages: MESSAGES,
      initiated_by: @initiated_by
    )
  end

  private

  attr_reader :start_date_input, :end_date_input, :mlb_game_id_input
end
