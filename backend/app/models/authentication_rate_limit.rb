class AuthenticationRateLimit < ApplicationRecord
  validates :action, :identifier_digest, :window_started_at, presence: true
  validates :attempt_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :expired, -> { where("window_started_at < ?", 1.day.ago) }
end
