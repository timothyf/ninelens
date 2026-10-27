class SeasonAwardSync < ApplicationRecord
  validates :season, numericality: { only_integer: true, greater_than: 1800 }
end
