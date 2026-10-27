class AdminTaskRun < ApplicationRecord
  belongs_to :initiated_by, class_name: "User", optional: true
  has_one :admin_task_upload, dependent: :destroy
  STATUSES = %w[queued running completed failed cancelled].freeze
  ACTIVE_STATUSES = %w[queued running].freeze
  TERMINAL_STATUSES = %w[completed failed cancelled].freeze

  validates :task_name, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :total_items, :completed_items, :failed_items,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :estimated_duration_seconds,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  scope :active, -> { where(status: ACTIVE_STATUSES) }
  scope :recent_first, -> { order(created_at: :desc) }

  def active?
    status.in?(ACTIVE_STATUSES)
  end

  def terminal?
    status.in?(TERMINAL_STATUSES)
  end

  def cancel_requested?
    cancel_requested_at.present?
  end

  def processed_items
    completed_items + failed_items
  end

  def progress_percentage
    return 100.0 if status == "completed"
    return 0.0 if total_items.zero?

    return [ (processed_items.to_f / total_items * 100).round(1), 100.0 ].min unless task_name == "pitch_data_sync"

    data = result_data.to_h
    base_percentage = processed_items.to_f
    if data["download_game_count"].to_i.positive?
      base_percentage += data["download_game_count"].to_i * data["download_chunk_fraction"].to_f
    end
    base_percentage = [ (base_percentage / total_items * 100).round(1), 100.0 ].min

    case data["progress_phase"]
    when "analytics"
      analytics_progress(data)
    when "complete"
      100.0
    else
      (base_percentage * 0.8).round(1)
    end
  end

  def analytics_progress(data)
    completed = data["analytics_completed_dates"].to_i
    total = data["analytics_total_dates"].to_i
    percentage = case data["analytics_work_phase"]
    when "dates"
      total.positive? ? 80.0 + (completed.to_f / total * 15.0) : 80.0
    when "benchmarks_started", "benchmarks"
      benchmark_total = data["analytics_benchmark_total"].to_i
      benchmark_completed = data["analytics_benchmark_completed"].to_i
      benchmark_total.positive? ? 95.0 + (benchmark_completed.to_f / benchmark_total * 4.0) : 95.0
    when "trend_events_started"
      99.0
    when "trend_events_finished"
      99.9
    else
      80.0
    end
    percentage.round(1).clamp(80.0, 99.9)
  end

  def elapsed_seconds
    return unless started_at

    ((finished_at || Time.current) - started_at).round
  end

  def estimated_remaining_seconds
    return unless active?

    if task_name == "pitch_data_sync" && result_data.to_h["progress_phase"] == "analytics"
      data = result_data.to_h
      completed, total, started_key = case data["analytics_work_phase"]
      when "benchmarks"
        [ data["analytics_benchmark_completed"].to_i, data["analytics_benchmark_total"].to_i, "analytics_benchmarks_started_at" ]
      when "dates"
        [ data["analytics_completed_dates"].to_i, data["analytics_total_dates"].to_i, "analytics_started_at" ]
      else
        return
      end
      analytics_started_at = Time.iso8601(data[started_key].to_s) if data[started_key].present?
      return unless analytics_started_at && completed.positive? && total > completed

      elapsed = Time.current - analytics_started_at
      return [ (elapsed / completed) * (total - completed), 0 ].max.round
    end

    return unless processed_items < total_items

    # Keep the estimate stable while an item is in flight. The baseline is
    # recalculated when an item completes, then simply counts down until the
    # next completion moves the anchor.
    anchor_at = remaining_time_anchor_at || (processed_items.positive? ? updated_at : started_at)
    return estimated_duration_seconds if anchor_at.nil?

    baseline_seconds = if processed_items.positive?
      return unless started_at

      elapsed_at_anchor = anchor_at - started_at
      elapsed_at_anchor.to_f / processed_items * (total_items - processed_items)
    else
      estimated_duration_seconds
    end
    return unless baseline_seconds

    [ baseline_seconds - (Time.current - anchor_at), 0 ].max.round
  end
end
