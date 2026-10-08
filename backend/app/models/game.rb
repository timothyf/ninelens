class Game < ApplicationRecord
  belongs_to :schedule
  belongs_to :home_team, class_name: "Team", inverse_of: :home_games
  belongs_to :away_team, class_name: "Team", inverse_of: :away_games
  belongs_to :home_probable_pitcher, class_name: "Player", optional: true
  belongs_to :away_probable_pitcher, class_name: "Player", optional: true
  has_many :pitches, class_name: "PitchDatum", dependent: :nullify, inverse_of: :game
  has_many :plate_appearances, dependent: :destroy
  has_many :game_player_batting_lines, dependent: :destroy
  has_many :game_player_pitching_lines, dependent: :destroy
  has_many :lineup_entries, dependent: :destroy

  validates :mlb_id, presence: true, uniqueness: true
  validates :official_date, presence: true
  validates :game_type, presence: true
  validates :status, presence: true
  validates :source_name, presence: true
  validates :last_synced_at, presence: true
  validates :home_score, :away_score, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :teams_must_be_distinct

  scope :chronological, -> { order(:official_date, :scheduled_at, :mlb_id) }
  scope :upcoming, -> { where(status: %w[scheduled preview]).where("official_date >= ?", Date.current).without_unplayed_if_necessary.chronological }
  scope :without_unplayed_if_necessary, -> {
    where.not(
      "games.status IN (?) AND COALESCE(games.raw_data ->> 'ifNecessary', 'N') = ?",
      %w[scheduled preview],
      "Y"
    )
  }
  scope :for_team, ->(team) { where(home_team: team).or(where(away_team: team)) }

  private

  def teams_must_be_distinct
    return if home_team_id.blank? || away_team_id.blank? || home_team_id != away_team_id

    errors.add(:away_team, "must be different from the home team")
  end
end
