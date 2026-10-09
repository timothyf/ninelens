require "rails_helper"

RSpec.describe PlayerBenchmarkSnapshotQuery do
  let(:player) { create_player }
  let(:start_date) { Date.new(2026, 3, 26) }
  let(:end_date) { Date.new(2026, 7, 15) }

  it "combines MLB and position context into one P1.5 metric payload" do
    league = create_benchmark(peer_group_type: "mlb", peer_group_key: "all", average_value: 0.720, player_count: 280)
    position = create_benchmark(peer_group_type: "position", peer_group_key: "CF", average_value: 0.745, player_count: 24)
    create_percentile(league, percentile: 82.5)
    create_percentile(position, percentile: 75.0)

    result = described_class.new(player: player).result

    expect(result).to include(
      available: true,
      source_start_date: start_date,
      source_end_date: end_date,
      calculation_version: DailyAnalyticsRefresh::CALCULATION_VERSION
    )
    expect(result.fetch(:metrics)).to contain_exactly(
      hash_including(
        metric_key: "ops",
        raw_value: 0.842,
        mlb_average: 0.72,
        position_average: 0.745,
        position_key: "CF",
        percentile: 82.5,
        position_percentile: 75.0,
        sample_size: 480,
        mlb_player_count: 280,
        position_player_count: 24
      )
    )
  end

  it "returns a stable unavailable payload before benchmarks are calculated" do
    expect(described_class.new(player: player).result).to include(
      available: false,
      calculation_version: DailyAnalyticsRefresh::CALCULATION_VERSION,
      metrics: []
    )
  end

  it "uses only cached benchmarks for the requested date range" do
    old_league = create_benchmark(peer_group_type: "mlb", peer_group_key: "all", average_value: 0.700, player_count: 280)
    create_percentile(old_league, {})
    requested_start = start_date + 1.day

    result = described_class.new(player: player, start_date: requested_start, end_date: end_date).result

    expect(result).to include(
      available: false,
      cached: false,
      source_start_date: requested_start,
      source_end_date: end_date,
      metrics: []
    )
  end

  it "previews a requested range when cached metrics predate current rate benchmarks" do
    league = create_benchmark(peer_group_type: "mlb", peer_group_key: "all", average_value: 0.720, player_count: 280)
    create_percentile(league, {})
    preview = {
      available: true,
      cached: false,
      source_start_date: start_date,
      source_end_date: end_date,
      calculation_version: DailyAnalyticsRefresh::CALCULATION_VERSION,
      calculated_at: Time.current,
      metrics: [ { metric_key: "batter_strikeout_percentage" } ]
    }
    allow(ContextualBenchmarkRefresh).to receive(:preview).with(
      player_id: player.id,
      start_date: start_date,
      end_date: end_date,
      calculation_version: DailyAnalyticsRefresh::CALCULATION_VERSION
    ).and_return(preview)

    result = described_class.new(player: player, start_date: start_date, end_date: end_date).result

    expect(result).to eq(preview)
  end

  def create_benchmark(attributes)
    LeagueMetricBenchmark.create!(
      {
        metric_key: "ops",
        metric_group: "batting",
        display_name: "OPS",
        dimension_type: "",
        dimension_value: "",
        directionality: "higher_better",
        sample_size: 10_000,
        source_start_date: start_date,
        source_end_date: end_date,
        calculation_version: DailyAnalyticsRefresh::CALCULATION_VERSION,
        calculated_at: Time.current,
        source_name: "NineLens contextual benchmarks",
        metadata: { "unit" => "rate" }
      }.merge(attributes)
    )
  end

  def create_percentile(benchmark, attributes)
    PlayerMetricPercentile.create!(
      {
        player: player,
        league_metric_benchmark: benchmark,
        raw_value: 0.842,
        percentile: 82.5,
        sample_size: 480,
        peer_player_count: benchmark.player_count,
        source_start_date: start_date,
        source_end_date: end_date,
        calculation_version: DailyAnalyticsRefresh::CALCULATION_VERSION,
        calculated_at: Time.current,
        source_name: "NineLens contextual benchmarks"
      }.merge(attributes)
    )
  end
end
