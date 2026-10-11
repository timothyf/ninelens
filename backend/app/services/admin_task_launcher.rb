class AdminTaskLauncher
  EnqueueFailure = Class.new(StandardError)

  def self.call(task_name:, params: {}, initiated_by: nil, estimate: nil, job_class: nil, total_count_key: nil, messages: nil)
    task_name = task_name.to_s
    if estimate
      return new(
        task_name:,
        estimate:,
        job_class:,
        total_count_key:,
        messages:,
        initiated_by:
      ).call
    end

    raise ArgumentError, "Unknown admin task: #{task_name}" unless AdminTaskRunner::TASKS.key?(task_name)

    new(
      task_name:,
      estimate: {
        task_parameters: params.to_h,
        total_items: 1,
        current_item_label: AdminTaskRunner::TASKS.fetch(task_name).fetch(:name)
      },
      job_class: AdminTaskJob,
      total_count_key: :total_items,
      messages: {
        already_active: "#{task_name.humanize} is already queued or running",
        enqueue_failure: "#{task_name.humanize} could not be enqueued"
      },
      initiated_by:,
      enqueue_failure_attributes: { failed_items: 1 }
    ).call
  end

  def initialize(task_name:, estimate:, job_class:, total_count_key:, messages:, initiated_by: nil, enqueue_failure_attributes: {})
    @task_name = task_name
    @estimate = estimate
    @job_class = job_class
    @total_count_key = total_count_key
    @messages = messages
    @initiated_by = initiated_by
    @enqueue_failure_attributes = enqueue_failure_attributes
  end

  def call
    raise ArgumentError, messages.fetch(:already_active) if AdminTaskRun.active.exists?(task_name:)

    run = AdminTaskRun.create!(task_run_attributes)
    job = job_class.perform_later(run.id)
    raise EnqueueFailure, messages.fetch(:enqueue_failure) unless job

    run
  rescue ActiveRecord::RecordNotUnique
    raise ArgumentError, messages.fetch(:already_active)
  rescue StandardError => error
    if enqueue_error?(error)
      run&.update(
        status: "failed",
        error_message: error.message,
        finished_at: Time.current,
        **enqueue_failure_attributes
      )
    end
    raise
  end

  private

  attr_reader :task_name, :estimate, :job_class, :total_count_key, :messages, :initiated_by,
    :enqueue_failure_attributes

  def task_run_attributes
    {
      task_name:,
      task_parameters: estimate.fetch(:task_parameters),
      total_items: estimate.fetch(total_count_key),
      estimated_duration_seconds: estimate[:estimated_seconds],
      current_item_label: estimate[:current_item_label],
      initiated_by:
    }.compact
  end

  def enqueue_error?(error)
    error.is_a?(EnqueueFailure) ||
      error.is_a?(SolidQueue::Job::EnqueueError) ||
      error.class.name == "ActiveJob::EnqueueError"
  end
end
