class AdminImportJob < ApplicationJob
  queue_as :default

  def perform(task_run_id)
    run = AdminTaskRun.find(task_run_id)
    return run.result_data if run.terminal?
    return cancel_before_start(run) if run.cancel_requested?

    mark_running(run)
    result = execute(run)
    result[:success] ? complete(run, result) : fail_run(run, result[:message], result)
    result
  rescue StandardError => error
    fail_run(run, error.message) if run&.persisted? && !run.terminal?
    { success: false, message: error.message, data: { errors: [ error.message ] } }
  ensure
    run&.admin_task_upload&.destroy
  end

  private

  def execute(run)
    parameters = run.task_parameters.with_indifferent_access

    case run.task_name
    when "player_season_stats_import"
      upload = run.admin_task_upload || raise("Staged CSV upload is unavailable")
      PlayerStatsImporter.call(
        csv_data: upload.contents,
        source_name: upload.original_filename,
        required_stat_columns: parameters[:required_stat_columns],
        replace_season: parameters[:replace_season]
      )
    when "pitch_data_import"
      upload = run.admin_task_upload || raise("Staged CSV upload is unavailable")
      PitchDataImporter.call(csv_data: upload.contents, source_name: upload.original_filename)
    when "player_season_stats_download"
      download_and_import_player_stats(parameters)
    else
      raise "Unsupported import task: #{run.task_name}"
    end
  end

  def download_and_import_player_stats(parameters)
    download = PlayerStatsDownloader.call(
      category: parameters[:category],
      start_year: parameters[:start_year],
      end_year: parameters[:end_year]
    )
    return download unless download[:success]

    imported = PlayerStatsImporter.call(
      csv_data: download.dig(:data, :csv_data),
      source_name: "MLB #{download.dig(:data, :category)} #{download.dig(:data, :seasons).join('-')}",
      replace_season: parameters[:replace_season]
    )
    return imported unless imported[:success]

    imported[:data] = imported.fetch(:data).merge(
      downloaded_count: download.dig(:data, :row_count),
      downloaded_category: download.dig(:data, :category),
      downloaded_seasons: download.dig(:data, :seasons)
    )
    imported
  end

  def mark_running(run)
    run.update!(
      status: "running",
      started_at: run.started_at || Time.current,
      last_heartbeat_at: Time.current,
      result_data: run.result_data.to_h.merge("active_execution_job_id" => job_id)
    )
  end

  def complete(run, result)
    run.update!(
      status: "completed",
      completed_items: 1,
      failed_items: 0,
      error_message: nil,
      current_item_label: nil,
      result_data: serialized_result(result),
      last_heartbeat_at: Time.current,
      finished_at: Time.current
    )
  end

  def fail_run(run, message, result = nil)
    run.update!(
      status: "failed",
      failed_items: 1,
      error_message: message,
      current_item_label: nil,
      result_data: serialized_result(result || { success: false, message: message, data: { errors: [ message ] } }),
      last_heartbeat_at: Time.current,
      finished_at: Time.current
    )
  end

  def cancel_before_start(run)
    run.update!(
      status: "cancelled",
      current_item_label: nil,
      result_data: { "success" => false, "message" => "Task cancelled before it started", "data" => { "cancelled" => true } },
      last_heartbeat_at: Time.current,
      finished_at: Time.current
    )
    run.result_data
  end

  def serialized_result(result)
    { "success" => result[:success], "message" => result[:message], "data" => result[:data] || {} }
  end
end
