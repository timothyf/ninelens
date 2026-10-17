class Game < ApplicationRecord
  CLINCHED_IF_NECESSARY_SQL = <<~SQL.squish.freeze
    NOT (
      games.status IN ('scheduled', 'preview')
      AND COALESCE(games.raw_data ->> 'ifNecessary', 'N') = 'Y'
      AND (
        SELECT GREATEST(
          COUNT(*) FILTER (WHERE
            (prior_games.home_team_id = games.home_team_id AND prior_games.home_score > prior_games.away_score)
            OR (prior_games.away_team_id = games.home_team_id AND prior_games.away_score > prior_games.home_score)
          ),
          COUNT(*) FILTER (WHERE
            (prior_games.home_team_id = games.away_team_id AND prior_games.home_score > prior_games.away_score)
            OR (prior_games.away_team_id = games.away_team_id AND prior_games.away_score > prior_games.home_score)
          )
        )
        FROM games prior_games
        INNER JOIN schedules prior_schedules ON prior_schedules.id = prior_games.schedule_id
        WHERE prior_games.status = 'final'
          AND prior_games.game_type = games.game_type
          AND LEAST(prior_games.home_team_id, prior_games.away_team_id) = LEAST(games.home_team_id, games.away_team_id)
          AND GREATEST(prior_games.home_team_id, prior_games.away_team_id) = GREATEST(games.home_team_id, games.away_team_id)
          AND prior_schedules.season = (SELECT season FROM schedules WHERE schedules.id = games.schedule_id)
      ) >= CASE games.game_type
        WHEN 'F' THEN 2
        WHEN 'D' THEN 3
        WHEN 'L' THEN 4
        WHEN 'W' THEN 4
        ELSE 99
      END
    )
  SQL

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
  scope :without_unplayed_if_necessary, -> { where(CLINCHED_IF_NECESSARY_SQL) }
  scope :without_cancelled, -> {
    where.not(status: %w[canceled cancelled])
      .where("LOWER(COALESCE(games.detailed_status, '')) NOT LIKE ?", "%cancel%ed%")
  }
  scope :for_team, ->(team) { where(home_team: team).or(where(away_team: team)) }

  private

  def teams_must_be_distinct
    return if home_team_id.blank? || away_team_id.blank? || home_team_id != away_team_id

    errors.add(:away_team, "must be different from the home team")
  end
end
