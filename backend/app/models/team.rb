class Team < ApplicationRecord
  # Historical imports reuse these franchise IDs. Keep the shared Team record's
  # identity current; the original season-specific names remain in source data.
  CURRENT_IDENTITIES = {
    113 => { name: "Cincinnati Reds", abbreviation: "CIN", team_name: "Reds", location_name: "Cincinnati", short_name: "Reds" },
    114 => { name: "Cleveland Guardians", abbreviation: "CLE", team_name: "Guardians", location_name: "Cleveland", short_name: "Guardians" },
    117 => { name: "Houston Astros", abbreviation: "HOU", team_name: "Astros", location_name: "Houston", short_name: "Astros" },
    119 => { name: "Los Angeles Dodgers", abbreviation: "LAD", team_name: "Dodgers", location_name: "Los Angeles", short_name: "Dodgers" },
    133 => { name: "Athletics", abbreviation: "ATH", team_name: "Athletics", location_name: "Athletics", short_name: "Athletics" },
    137 => { name: "San Francisco Giants", abbreviation: "SF", team_name: "Giants", location_name: "San Francisco", short_name: "Giants" },
    140 => { name: "Texas Rangers", abbreviation: "TEX", team_name: "Rangers", location_name: "Texas", short_name: "Rangers" },
    142 => { name: "Minnesota Twins", abbreviation: "MIN", team_name: "Twins", location_name: "Minnesota", short_name: "Twins" },
    144 => { name: "Atlanta Braves", abbreviation: "ATL", team_name: "Braves", location_name: "Atlanta", short_name: "Braves" }
  }.freeze

  before_validation :preserve_current_identity

  has_many :need_profiles, dependent: :destroy
  has_many :players, dependent: :destroy
  has_many :player_season_fielding_stats, dependent: :nullify
  has_many :team_memberships, dependent: :destroy
  has_many :membership_players, through: :team_memberships, source: :player
  has_many :outgoing_trade_participants, class_name: "TradeParticipant", foreign_key: :from_team_id, dependent: :nullify
  has_many :incoming_trade_participants, class_name: "TradeParticipant", foreign_key: :to_team_id, dependent: :nullify
  has_many :rosters, dependent: :destroy
  has_many :roster_snapshots, dependent: :destroy
  has_many :home_games, class_name: "Game", foreign_key: :home_team_id, inverse_of: :home_team, dependent: :restrict_with_error
  has_many :away_games, class_name: "Game", foreign_key: :away_team_id, inverse_of: :away_team, dependent: :restrict_with_error
  has_many :game_player_batting_lines, dependent: :restrict_with_error
  has_many :game_player_pitching_lines, dependent: :restrict_with_error
  has_many :lineup_entries, dependent: :restrict_with_error
  has_many :player_batting_daily, dependent: :restrict_with_error
  has_many :player_pitching_daily, dependent: :restrict_with_error
  has_many :pitcher_pitch_type_daily, dependent: :nullify
  has_many :batter_split_summaries, dependent: :nullify
  has_many :pitcher_split_summaries, dependent: :nullify
  has_many :team_daily_metrics, dependent: :restrict_with_error
  has_many :opponent_reports, dependent: :destroy
  has_many :lineup_scenarios, dependent: :destroy
  has_many :reports_as_opponent, class_name: "OpponentReport", foreign_key: :opponent_team_id,
    inverse_of: :opponent_team, dependent: :restrict_with_error

  def logo_url
    "#{NineLensConfig.fetch(:external_services, :mlb_assets, :static_base_url)}/team-logos/#{mlb_id}.svg"
  end

  validates :mlb_id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :abbreviation, presence: true
  validates :team_name, presence: true
  validates :location_name, presence: true
  validates :short_name, presence: true
  validates :team_code, presence: true
  validates :file_code, presence: true

  private

  def preserve_current_identity
    attributes = CURRENT_IDENTITIES[mlb_id]
    assign_attributes(attributes) if attributes
  end
end
