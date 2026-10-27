class SeasonAward < ApplicationRecord
  AWARD_GROUPS = {
    "MVP" => { "AL" => "ALMVP", "NL" => "NLMVP" },
    "Cy Young" => { "AL" => "ALCY", "NL" => "NLCY" },
    "Gold Glove" => { "AL" => "ALGG", "NL" => "NLGG" }
  }.freeze
  AWARD_IDS = AWARD_GROUPS.values.flat_map(&:values).freeze

  validates :season, numericality: { only_integer: true, greater_than: 1800 }
  validates :award_id, inclusion: { in: AWARD_IDS }
  validates :award_name, :player_name, :source_url, presence: true
  validates :player_mlb_id, numericality: { only_integer: true, greater_than: 0 }
  validates :player_mlb_id, uniqueness: { scope: [ :season, :award_id ] }
end
