class DailyAnalyticsRefresh
  CALCULATION_VERSION = "1.1.0"
  SOURCE_NAME = "NineLens daily analytics"
  SUMMARY_MODELS = [
    PlayerBattingDaily,
    PlayerPitchingDaily,
    PitcherPitchTypeDaily,
    BatterSplitSummary,
    PitcherSplitSummary,
    TeamDailyMetric
  ].freeze

  def self.call(start_date: nil, end_date: nil, dates: nil, calculation_version: CALCULATION_VERSION, refresh_contextual_benchmarks: true)
    new(
      start_date: start_date,
      end_date: end_date,
      dates: dates,
      calculation_version: calculation_version,
      refresh_contextual_benchmarks: refresh_contextual_benchmarks
    ).call
  end

  def initialize(start_date: nil, end_date: nil, dates: nil, calculation_version: CALCULATION_VERSION, refresh_contextual_benchmarks: true)
    @start_date = start_date
    @end_date = end_date
    @dates = dates
    @calculation_version = calculation_version.to_s.strip
    @refresh_contextual_benchmarks = refresh_contextual_benchmarks
  end

  def call
    calculation_dates = normalized_dates
    return failure("At least one calculation date is required") if calculation_dates.empty?
    return failure("Calculation version is required") if calculation_version.blank?

    totals = SUMMARY_MODELS.to_h { |model| [ model.table_name, 0 ] }
    calculation_dates.each do |date|
      counts = DailyAnalyticsCalculator.call(metric_date: date, calculation_version: calculation_version)
      counts.each { |table, count| totals[table] += count }
    end
    benchmark_refreshes = refresh_contextual_benchmarks ? refresh_contextual_benchmark_ranges(calculation_dates) : []
    trend_event_refresh = refresh_trend_events(calculation_dates)

    {
      success: true,
      message: "Refreshed daily analytics for #{calculation_dates.length} #{'date'.pluralize(calculation_dates.length)}",
      data: {
        calculation_version: calculation_version,
        source_start_date: calculation_dates.min.iso8601,
        source_end_date: calculation_dates.max.iso8601,
        calculated_date_count: calculation_dates.length,
        row_counts: totals,
        trend_event_refresh: trend_event_refresh,
        contextual_benchmarks_refreshed: refresh_contextual_benchmarks,
        benchmark_refreshes: benchmark_refreshes
      }
    }
  rescue ArgumentError => error
    failure(error.message)
  rescue ActiveRecord::ActiveRecordError => error
    failure("Failed to refresh daily analytics: #{error.message}")
  end

  private

  attr_reader :start_date, :end_date, :dates, :calculation_version, :refresh_contextual_benchmarks

  def refresh_trend_events(calculation_dates)
    mlb_ids = PitchDatum.where(game_date: calculation_dates)
      .pluck(:pitcher, :batter)
      .flatten
      .compact
      .uniq
    players = Player.where(mlb_id: mlb_ids).to_a
    return { success: true, data: { players: 0, created: 0, updated: 0, resolved: 0 } } if players.empty?

    PlayerTrendEventRefresh.call(players: players, as_of: calculation_dates.max)
  end

  def refresh_contextual_benchmark_ranges(calculation_dates)
    calculation_dates.map(&:year).uniq.sort.flat_map do |year|
      year_range = Date.new(year, 1, 1)..Date.new(year, 12, 31)
      stored_dates = SUMMARY_MODELS.flat_map do |model|
        scope = model.where(calculation_version: calculation_version, metric_date: year_range)
        table = model.arel_table
        scope.pick(table[:metric_date].minimum, table[:metric_date].maximum)
      end.compact
      next if stored_dates.empty?

      last_date = stored_dates.max
      ranges = [
        [ Date.new(year, 1, 1), last_date ],
        *[ 7, 14, 30 ].map { |days| [ last_date - (days - 1).days, last_date ] }
      ].uniq
      ranges.map do |range_start, range_end|
        ContextualBenchmarkRefresh.call(
          start_date: range_start,
          end_date: range_end,
          calculation_version: calculation_version
        )
      end
    end.compact
  rescue StandardError => error
    [ { success: false, message: "Daily summaries were refreshed, but contextual benchmarks failed: #{error.message}" } ]
  end

  def normalized_dates
    values = if dates.present?
      Array(dates)
    elsif start_date.present?
      first = parse_date(start_date)
      last = end_date.present? ? parse_date(end_date) : first
      raise ArgumentError, "End date must be on or after start date" if last < first

      (first..last).to_a
    else
      []
    end

    values.filter_map { |value| parse_date(value) }.uniq.sort
  end

  def parse_date(value)
    return value if value.is_a?(Date)

    Date.iso8601(value.to_s)
  rescue Date::Error
    raise ArgumentError, "Analytics dates must be valid ISO dates"
  end

  def failure(message)
    { success: false, message: message, data: { errors: [ message ] } }
  end
end
