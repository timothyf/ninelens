class Alert < ApplicationRecord
  STATUSES = %w[active acknowledged snoozed resolved].freeze

  belongs_to :user
  belongs_to :player_trend_event
  belongs_to :alert_subscription, optional: true
  belongs_to :assigned_to, class_name: "User", optional: true

  validates :status, inclusion: { in: STATUSES }

  scope :inbox, -> { where.not(status: "resolved") }
  scope :recent_first, -> { order(created_at: :desc) }

  def acknowledge!
    update!(status: "acknowledged", acknowledged_at: Time.current, snoozed_until: nil)
  end

  def snooze!(until_at:)
    update!(status: "snoozed", snoozed_until: until_at, acknowledged_at: nil)
  end

  def resolve!
    update!(status: "resolved", resolved_at: Time.current)
  end

  def reopen_if_snooze_expired!
    update!(status: "active", snoozed_until: nil) if status == "snoozed" && snoozed_until.present? && snoozed_until <= Time.current
  end
end
