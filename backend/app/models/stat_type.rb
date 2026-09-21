class StatType < ApplicationRecord
  class_attribute :catalog_cache, instance_accessor: false

  has_many :player_season_stats, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :category }
  validates :label, presence: true
  validates :category, presence: true

  after_commit :invalidate_catalog_cache

  class << self
    def load_catalog_cache!
      self.catalog_cache = all.to_a
    end

    def cached_all
      catalog_cache || load_catalog_cache!
      catalog_cache
    end

    def cached_where(category: nil, name: nil)
      records = cached_all
      records = records.select { |stat_type| stat_type.category == category } if category
      records = records.select { |stat_type| Array(name).map(&:to_s).include?(stat_type.name) } if name
      records
    end

    def cached_find_by(category:, name:)
      cached_where(category: category, name: name).first
    end

    def cached_find(id)
      cached_all.find { |stat_type| stat_type.id == id }
    end

    def invalidate_catalog_cache!
      self.catalog_cache = nil
    end
  end

  private

  def invalidate_catalog_cache
    self.class.invalidate_catalog_cache!
  end
end
