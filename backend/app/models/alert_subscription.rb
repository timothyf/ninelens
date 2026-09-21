class AlertSubscription < ApplicationRecord
  SEVERITIES = %w[warning critical].freeze

  belongs_to :user
  belongs_to :player, optional: true
  belongs_to :watchlist, optional: true
  has_many :alerts, dependent: :nullify

  validates :minimum_severity, inclusion: { in: SEVERITIES }
  validate :has_one_target

  scope :enabled, -> { where(enabled: true) }

  def matches?(event)
    return false unless enabled?
    return false if minimum_severity == "critical" && event.severity != "critical"
    return false if event_types.present? && !event_types.include?(event.event_type)
    player_id == event.player_id || (watchlist_id.present? && watchlist.entries.where(player_id: event.player_id).exists?)
  end

  private

  def has_one_target
    errors.add(:base, "choose a player or watchlist") unless player_id.present? ^ watchlist_id.present?
  end
end
