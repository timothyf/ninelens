class ComparisonBenchmarkSnapshotQuery
  OPPORTUNITY_ALIASES = {
    "batting" => %w[plateAppearances PA atBats AB],
    "pitching" => %w[inningsPitched IP battersFaced TBF]
  }.freeze
  ADVANCED_DEFINITIONS = {
    "batting" => [
      { key: "k_percentage", aliases: %w[K% strikeoutsPerPlateAppearance] },
      { key: "bb_percentage", aliases: %w[BB% walksPerPlateAppearance] },
      { key: "iso", aliases: %w[ISO iso] },
      { key: "wrc_plus", aliases: %w[wRC+ wrc+ wRCPlus wrcPlus] },
      { key: "ops_plus", aliases: %w[OPS+ ops+ OPSPlus opsPlus] },
      { key: "baserunning_runs", aliases: %w[BaseRunning baserunningRuns] }
    ],
    "pitching" => [
      { key: "k_percentage", aliases: %w[K% strikeoutPercentage] },
      { key: "bb_percentage", aliases: %w[BB% walkPercentage] },
      { key: "k_minus_bb_percentage", aliases: %w[K-BB% kMinusBbPercentage] },
      { key: "era_minus", aliases: %w[ERA- eraMinus] },
      { key: "fip", aliases: %w[FIP fip] },
      { key: "fip_minus", aliases: %w[FIP- fipMinus] },
      { key: "xfip", aliases: %w[xFIP xfip] },
      { key: "xfip_minus", aliases: %w[xFIP- xfipMinus] },
      { key: "whip", aliases: %w[WHIP whip] }
    ]
  }.freeze
  BATTER_PER_OPPORTUNITY_KEYS = %w[runs hits doubles triples homeRuns rbi baseOnBalls strikeOuts stolenBases caughtStealing].freeze
  PERCENTAGE_KEYS = %w[k_percentage bb_percentage k_minus_bb_percentage].freeze
  RATE_STAT_NAMES = %w[AVG avg OBP obp SLG slg OPS ops ISO iso wOBA wRC+ wrc+ OPS+ ops+ ERA era FIP fip xFIP xfip WHIP whip ERA- eraMinus FIP- fipMinus xFIP- xfipMinus].freeze
  LOWER_IS_BETTER = {
    "batting" => %w[strikeOuts caughtStealing k_percentage],
    "pitching" => %w[L ERA hits runs ER homeRuns hitByPitch baseOnBalls whip avg bb_percentage era_minus fip fip_minus xfip xfip_minus]
  }.freeze
  QUALIFIERS = { "batting" => 200, "pitching" => 50 }.freeze

  def initialize(season:, category:)
    @season = season
    @category = category
  end

  def result
    return {} if season.blank? || !PlayerSeasonStatsLeaderboardQuery::COLUMN_DEFINITIONS_BY_CATEGORY.key?(category)

    definitions = PlayerSeasonStatsLeaderboardQuery::COLUMN_DEFINITIONS_BY_CATEGORY.fetch(category) + ADVANCED_DEFINITIONS.fetch(category, [])
    stat_names = definitions.flat_map { |definition| definition.fetch(:aliases) } + OPPORTUNITY_ALIASES.fetch(category)
    rows = PlayerSeasonStat.joins(:stat_type).where(
      season: season,
      scope_type: %w[combined team],
      stat_types: { category: category, name: stat_names.uniq }
    ).pluck(:player_id, "stat_types.name", :value, :scope_type, :scope_key)
    values_by_player = rows.group_by(&:first).transform_values do |player_rows|
      aggregate_player_values(player_rows)
    end
    qualified_values = values_by_player.select { |_player_id, values| qualified?(values) }

    definitions.each_with_object({}) do |definition, benchmarks|
      key = definition.fetch(:key)
      values = qualified_values.filter_map do |_player_id, player_values|
        raw_value = metric_value(key, player_values, definition.fetch(:aliases))
        next if raw_value.nil?

        normalized_value(key, raw_value, player_values)
      end
      next if values.length < 5

      benchmarks[key] = distribution(values).merge(
        directionality: LOWER_IS_BETTER.fetch(category, []).include?(key) ? "lower_better" : "higher_better",
        player_count: values.length,
        season: season,
        category: category
      )
    end
  end

  private

  attr_reader :season, :category

  def qualified?(values)
    opportunity = if category == "batting"
      preferred_value(values, %w[plateAppearances PA]) || preferred_value(values, %w[atBats AB])
    else
      innings = preferred_value(values, %w[inningsPitched IP])
      innings || preferred_value(values, %w[battersFaced TBF]).to_f / 3.0
    end
    opportunity.to_f >= QUALIFIERS.fetch(category)
  end

  def preferred_value(values, aliases)
    aliases.lazy.map { |alias_name| values[alias_name] }.find(&:present?)
  end

  def aggregate_player_values(player_rows)
    grouped = player_rows.group_by { |_player_id, name, _value, _scope_type, _scope_key| name }
    combined_values = grouped.each_with_object({}) do |(name, rows), values|
      combined = rows.find { |_player_id, _name, _value, scope_type, _scope_key| scope_type == "combined" }
      values[name] = if combined
        combined[2].to_f
      elsif rate_stat?(name)
        weighted_team_value(name, rows, grouped)
      else
        rows.sum { |_player_id, _name, value, _scope_type, _scope_key| value.to_f }
      end
    end
    combined_values
  end

  def rate_stat?(name)
    RATE_STAT_NAMES.include?(name) || name.to_s.include?("%")
  end

  def weighted_team_value(name, rows, grouped)
    weight_aliases = if category == "batting"
      %w[plateAppearances PA atBats AB]
    elsif name.to_s.include?("%")
      %w[battersFaced TBF]
    else
      %w[inningsPitched IP]
    end
    weights_by_scope = grouped.each_with_object({}) do |(stat_name, stat_rows), weights|
      next unless weight_aliases.include?(stat_name)

      stat_rows.each do |_player_id, _name, value, scope_type, scope_key|
        next if scope_type == "combined"

        weights[[scope_type, scope_key]] = value.to_f
      end
    end
    weighted_rows = rows.filter_map do |_player_id, _name, value, scope_type, scope_key|
      weight = weights_by_scope[[scope_type, scope_key]]
      next if weight.nil? || weight <= 0

      [value.to_f, weight]
    end
    return rows.sum { |_player_id, _name, value, _scope_type, _scope_key| value.to_f } / rows.length if weighted_rows.empty?

    weighted_rows.sum { |value, weight| value * weight } / weighted_rows.sum(&:last)
  end

  def normalized_value(key, value, values)
    if PERCENTAGE_KEYS.include?(key) && value.to_f.abs > 1
      return value.to_f / 100.0
    end
    return value unless category == "batting" && BATTER_PER_OPPORTUNITY_KEYS.include?(key)

    opportunity = preferred_value(values, %w[plateAppearances PA atBats AB]).to_f
    opportunity.positive? ? value / opportunity : nil
  end

  def metric_value(key, values, aliases)
    value = preferred_value(values, aliases)
    return value if value.present?
    return nil unless key == "k_minus_bb_percentage"

    strikeout_rate = preferred_value(values, %w[K% strikeoutPercentage]).to_f
    walk_rate = preferred_value(values, %w[BB% walkPercentage]).to_f
    return if strikeout_rate.zero? && walk_rate.zero?

    strikeout_rate - walk_rate
  end

  def distribution(values)
    sorted = values.sort
    median = quantile(sorted, 0.5)
    deviations = sorted.map { |value| (value - median).abs }.sort
    {
      p05: quantile(sorted, 0.05),
      median: median,
      mad: quantile(deviations, 0.5),
      p95: quantile(sorted, 0.95)
    }
  end

  def quantile(values, probability)
    position = probability * (values.length - 1)
    lower = position.floor
    upper = position.ceil
    return values[lower] if lower == upper

    values[lower] + (values[upper] - values[lower]) * (position - lower)
  end
end
