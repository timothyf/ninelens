class Player < ApplicationRecord
  belongs_to :team
  has_one :profile, class_name: "PlayerProfile", dependent: :destroy, inverse_of: :player
  has_many :player_season_stats, dependent: :destroy
  has_many :player_season_fielding_stats, dependent: :destroy
  has_many :trade_participants, dependent: :nullify
  has_many :trades, through: :trade_participants
  has_many :team_memberships, dependent: :destroy
  has_many :membership_teams, through: :team_memberships, source: :team
  has_many :player_positions, dependent: :destroy
  has_many :positions, through: :player_positions
  has_many :roster_players, dependent: :destroy
  has_many :rosters, through: :roster_players
  has_many :roster_snapshot_players, dependent: :nullify
  has_many :roster_snapshots, through: :roster_snapshot_players
  has_many :home_probable_pitcher_games, class_name: "Game", foreign_key: :home_probable_pitcher_id, dependent: :nullify
  has_many :away_probable_pitcher_games, class_name: "Game", foreign_key: :away_probable_pitcher_id, dependent: :nullify
  has_many :game_player_batting_lines, dependent: :destroy
  has_many :game_player_pitching_lines, dependent: :destroy
  has_many :batting_plate_appearances, class_name: "PlateAppearance", foreign_key: :batter_id, dependent: :nullify
  has_many :pitching_plate_appearances, class_name: "PlateAppearance", foreign_key: :pitcher_id, dependent: :nullify
  has_many :lineup_entries, dependent: :destroy
  has_many :lineup_scenario_entries, dependent: :destroy
  has_many :watchlist_entries, dependent: :destroy
  has_many :player_batting_daily, dependent: :destroy
  has_many :player_pitching_daily, dependent: :destroy
  has_many :pitcher_pitch_type_daily, dependent: :destroy
  has_many :batter_split_summaries, dependent: :destroy
  has_many :pitcher_split_summaries, dependent: :destroy
  has_many :player_metric_percentiles, dependent: :destroy
  has_many :trend_events, class_name: "PlayerTrendEvent", dependent: :destroy, inverse_of: :player
  has_many :alert_subscriptions, dependent: :destroy
  has_one :player_id_mapping, primary_key: :mlb_id, foreign_key: :mlb_id

  validates :mlb_id, presence: true, uniqueness: true
  validates :first_name, presence: true
  validates :last_name, presence: true

  def full_name
    [ first_name, last_name ].compact.join(" ")
  end

  def primary_position(season: nil)
    player_positions.includes(:position).find_by(season: season, is_primary: true)&.position
  end

  # players.team_id is a denormalized current-team cache. Historical and
  # date-specific team ownership must always be read from TeamMembership.
  def current_team_membership(on: Date.current)
    team_memberships.active_on(on).includes(:team).to_a.min_by do |membership|
      [ MlbRosterStatus.priority(membership.roster_status), -membership.starts_on.jd, membership.id ]
    end
  end

  def refresh_current_team!(on: Date.current)
    membership = current_team_membership(on: on)
    update!(team: membership.team) if membership.present? && team_id != membership.team_id
    membership&.team
  end

  def display_team
    return current_team_membership&.team || team unless profile&.raw_data.to_h["active"] == false

    team_id_with_most_seasons = player_season_stats
      .where.not(team_id: nil)
      .pluck(:team_id, :season)
      .group_by(&:first)
      .max_by { |team_id, rows| [ rows.map(&:last).uniq.length, rows.map(&:last).max || 0, team_id ] }
      &.first

    Team.find_by(id: team_id_with_most_seasons) || team
  end
end
