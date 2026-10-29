class ScheduledGameDetailsSyncJob < ApplicationJob
  queue_as :default

  def perform
    setting = AutomationSetting.game_details_sync
    setting.with_lock do
      next unless setting.enabled?
      next if setting.last_started_at && Time.current < setting.last_started_at + setting.interval_minutes.minutes
      AdminTaskRun.active.where(task_name: MlbGameDetailsTaskLauncher::TASK_NAME).find_each do |run|
        AdminTaskRunReconciler.call(run)
      end
      next if AdminTaskRun.active.exists?(task_name: MlbGameDetailsTaskLauncher::TASK_NAME)

      date = Time.current.in_time_zone("America/Detroit").to_date
      next if MlbGameDetailsTaskEstimate.call(start_date: date, end_date: date)[:game_count].zero?

      MlbGameDetailsTaskLauncher.call(start_date: date, end_date: date)
      setting.update!(last_started_at: Time.current)
    end
  rescue ArgumentError => error
    raise unless error.message == MlbGameDetailsTaskLauncher::MESSAGES.fetch(:already_active)
  end
end
