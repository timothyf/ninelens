class PitchDatum < ApplicationRecord
  # The pitch_data table has a `type` column for pitch types (e.g. "FF", "SL").
  # Override Rails' STI inheritance_column so it doesn't collide with that field.
  self.inheritance_column = :_type_disabled

  belongs_to :game, optional: true, inverse_of: :pitches
  belongs_to :plate_appearance, optional: true, inverse_of: :pitches

  validates :game_pk, presence: true
  validates :at_bat_number, presence: true
  validates :pitch_number, presence: true
end
