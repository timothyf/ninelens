require "digest"

class AdminImportTaskLauncher
  EnqueueFailure = Class.new(StandardError)
  TASK_NAMES = %w[
    player_season_stats_import
    player_season_stats_download
    pitch_data_import
  ].freeze

  def self.call(task_name:, params: {}, uploaded_file: nil, initiated_by: nil)
    task_name = task_name.to_s
    raise ArgumentError, "Unknown import task: #{task_name}" unless task_name.in?(TASK_NAMES)
    raise ArgumentError, "CSV file is required" if task_name.end_with?("_import") && uploaded_file.blank?
    raise ArgumentError, "#{task_name.humanize} is already queued or running" if AdminTaskRun.active.exists?(task_name:)

    contents = uploaded_file&.read
    raise ArgumentError, "CSV file is empty" if uploaded_file && contents.blank?

    run = AdminTaskRun.transaction do
      created_run = AdminTaskRun.create!(
        task_name:,
        task_parameters: params.to_h,
        total_items: 1,
        current_item_label: uploaded_file&.original_filename || task_name.humanize,
        initiated_by:
      )
      if uploaded_file
        created_run.create_admin_task_upload!(
          original_filename: uploaded_file.original_filename,
          content_type: uploaded_file.content_type,
          byte_size: contents.bytesize,
          checksum: Digest::SHA256.hexdigest(contents),
          contents:
        )
      end
      created_run
    end

    job = AdminImportJob.perform_later(run.id)
    raise EnqueueFailure, "#{task_name.humanize} could not be enqueued" unless job
    run
  rescue ActiveRecord::RecordNotUnique
    raise ArgumentError, "#{task_name.humanize} is already queued or running"
  rescue StandardError => error
    if enqueue_error?(error)
      run&.update(status: "failed", error_message: error.message, failed_items: 1, finished_at: Time.current)
      run&.admin_task_upload&.destroy
    end
    raise
  end

  def self.enqueue_error?(error)
    error.is_a?(EnqueueFailure) ||
      error.is_a?(SolidQueue::Job::EnqueueError) ||
      error.class.name == "ActiveJob::EnqueueError"
  end
  private_class_method :enqueue_error?
end
