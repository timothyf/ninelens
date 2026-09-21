class PlayerSeasonStat < ApplicationRecord
  SCOPE_TYPES = %w[team combined league].freeze

  belongs_to :team, optional: true
  belongs_to :player
  belongs_to :stat_type

  before_validation :normalize_scope_fields
  after_find :hydrate_stat_type_from_catalog

  validates :season, presence: true
  validates :value, presence: true, numericality: true
  validates :scope_type, presence: true, inclusion: { in: SCOPE_TYPES }
  validates :scope_key, presence: true

  private

  def hydrate_stat_type_from_catalog
    stat_type = StatType.cached_find(stat_type_id)
    association(:stat_type).target = stat_type if stat_type
  end

  def normalize_scope_fields
    self.scope_type = scope_type.to_s.presence || infer_scope_type
    self.scope_key = scope_key.to_s.presence || infer_scope_key
  end

  def infer_scope_type
    return "team" if team_id.present?

    "combined"
  end

  def infer_scope_key
    return "TOT" if scope_type == "combined"
    return "MLB" if scope_type == "league"

    team&.abbreviation.presence || team_id.to_s
  end
end
