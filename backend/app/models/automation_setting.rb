class AutomationSetting < ApplicationRecord
  GAME_DETAILS_SYNC = "game_details_sync".freeze

  validates :key, presence: true
  validates :interval_minutes, numericality: { only_integer: true, in: 5..1440 }

  def self.game_details_sync
    create_or_find_by!(key: GAME_DETAILS_SYNC)
  end
end
