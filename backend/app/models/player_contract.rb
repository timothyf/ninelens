class PlayerContract < ApplicationRecord
  belongs_to :player

  validates :season, presence: true
  validates :source_url, presence: true
  validates :fetched_at, presence: true

  scope :current, -> { where(season: Date.current.year) }
end
