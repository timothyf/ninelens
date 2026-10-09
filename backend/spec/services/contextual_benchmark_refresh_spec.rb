require "rails_helper"

RSpec.describe ContextualBenchmarkRefresh, type: :service do
  let(:date) { Date.new(2026, 7, 15) }
  let(:team) { create_team }
  let(:batter_one) { create_player(team: team) }
  let(:batter_two) { create_player(team: team) }
  let(:starter) { create_player(team: team) }
  let(:reliever) { create_player(team: team) }

  before do
    third_base = create_position(mlb_code: "5", abbreviation: "3B", name: "Third Base", position_type: "infielder")
    create_player_position(player: batter_one, position: third_base, attributes: { is_primary: true })
    create_player_position(player: batter_two, position: third_base, attributes: { is_primary: true })

    create_batting_daily(batter_one, date, plate_appearances: 5, at_bats: 4, hits: 2, doubles: 1, triples: 0, home_runs: 0, walks: 1, strikeouts: 1)
    create_batting_daily(batter_two, date, plate_appearances: 4, at_bats: 4, hits: 1, doubles: 0, triples: 0, home_runs: 0, walks: 0, strikeouts: 2)

    create_batter_split(batter_one, date, average_exit_velocity: 100, maximum_exit_velocity: 110, barrel_count: 1, barrel_sample_size: 2, average_bat_speed: 76, bat_speed_sample_size: 4, batted_balls: 2, hard_hit_percentage: 100, swings: 4, whiffs: 1, chase_opportunities: 4, chases: 1)
    create_batter_split(batter_two, date, average_exit_velocity: 90, maximum_exit_velocity: 105, barrel_count: 0, barrel_sample_size: 2, average_bat_speed: 72, bat_speed_sample_size: 4, batted_balls: 2, hard_hit_percentage: 0, swings: 4, whiffs: 2, chase_opportunities: 4, chases: 2)

    create_pitching_daily(starter, games: 1, games_started: 1, batters_faced: 5, strikeouts: 2, walks: 1)
    create_pitching_daily(reliever, games: 1, games_started: 0, batters_faced: 5, strikeouts: 1, walks: 2)
    create_pitcher_split(starter, average_velocity: 96, average_spin_rate: 2400, swings: 5, whiffs: 2, chase_opportunities: 4, chases: 2)
    create_pitcher_split(reliever, average_velocity: 94, average_spin_rate: 2200, swings: 5, whiffs: 1, chase_opportunities: 4, chases: 1)
    create_pitch_type(starter, "FF", 80)
    create_pitch_type(starter, "SL", 20)
    create_pitch_type(reliever, "FF", 50)
    create_pitch_type(reliever, "SL", 50)
  end

  it "builds weighted MLB, position, role, percentile, and sample context" do
    result = described_class.call(start_date: date, end_date: date)

    expect(result).to include(success: true)
    expect(result.dig(:data, :benchmark_count)).to be > 10
    expect(result.dig(:data, :percentile_count)).to be > result.dig(:data, :benchmark_count)

    mlb_ops = LeagueMetricBenchmark.find_by!(metric_key: "ops", peer_group_type: "mlb")
    position_ops = LeagueMetricBenchmark.find_by!(metric_key: "ops", peer_group_type: "position", peer_group_key: "3B")
    expect(mlb_ops.average_value.to_f).to be_within(0.0001).of(0.9444)
    expect(position_ops.average_value).to eq(mlb_ops.average_value)
    expect(mlb_ops).to have_attributes(sample_size: 9, player_count: 2)

    batter_percentile = PlayerMetricPercentile.find_by!(player: batter_one, league_metric_benchmark: mlb_ops)
    expect(batter_percentile.percentile.to_f).to eq(75.0)
    expect(batter_percentile.raw_value.to_f).to eq(1.35)
    expect(batter_percentile.sample_size).to eq(5)

    exit_velocity = LeagueMetricBenchmark.find_by!(metric_key: "average_exit_velocity", peer_group_type: "mlb")
    expect(exit_velocity.average_value.to_f).to eq(95.0)
    maximum_exit_velocity = LeagueMetricBenchmark.find_by!(metric_key: "maximum_exit_velocity", peer_group_type: "mlb")
    expect(maximum_exit_velocity.average_value.to_f).to eq(107.5)
    barrel_rate = LeagueMetricBenchmark.find_by!(metric_key: "barrel_percentage", peer_group_type: "mlb")
    expect(barrel_rate.average_value.to_f).to eq(25.0)
    bat_speed = LeagueMetricBenchmark.find_by!(metric_key: "average_bat_speed", peer_group_type: "mlb")
    expect(bat_speed.average_value.to_f).to eq(74.0)
    chase = LeagueMetricBenchmark.find_by!(metric_key: "batter_chase_percentage", peer_group_type: "mlb")
    expect(chase.average_value.to_f).to eq(37.5)
    expect(PlayerMetricPercentile.find_by!(player: batter_one, league_metric_benchmark: chase).percentile.to_f).to eq(75.0)
    batter_strikeout_rate = LeagueMetricBenchmark.find_by!(metric_key: "batter_strikeout_percentage", peer_group_type: "mlb")
    batter_walk_rate = LeagueMetricBenchmark.find_by!(metric_key: "batter_walk_percentage", peer_group_type: "mlb")
    expect(batter_strikeout_rate.average_value.to_f).to be_within(0.0001).of(33.333333)
    expect(batter_walk_rate.average_value.to_f).to be_within(0.0001).of(11.111111)

    starter_velocity = LeagueMetricBenchmark.find_by!(metric_key: "pitcher_average_velocity", peer_group_type: "pitcher_role", peer_group_key: "starter")
    expect(starter_velocity.average_value.to_f).to eq(96.0)
    pitcher_strikeout_rate = LeagueMetricBenchmark.find_by!(metric_key: "pitcher_strikeout_percentage", peer_group_type: "mlb")
    pitcher_walk_rate = LeagueMetricBenchmark.find_by!(metric_key: "pitcher_walk_percentage", peer_group_type: "mlb")
    expect(pitcher_strikeout_rate.average_value.to_f).to eq(30.0)
    expect(pitcher_walk_rate.average_value.to_f).to eq(30.0)
    usage = LeagueMetricBenchmark.find_by!(metric_key: "pitch_usage_percentage", dimension_value: "FF", peer_group_type: "mlb")
    expect(usage.average_value.to_f).to eq(65.0)
    expect(usage.sample_size).to eq(200)
  end

  it "replaces a date range idempotently" do
    described_class.call(start_date: date, end_date: date)
    counts = [ LeagueMetricBenchmark.count, PlayerMetricPercentile.count ]

    described_class.call(start_date: date, end_date: date)

    expect([ LeagueMetricBenchmark.count, PlayerMetricPercentile.count ]).to eq(counts)
  end

  it "limits Statcast percentile pools to players meeting MLB's team-game qualifier" do
    low_sample_batter = create_player(team: team)
    create_batting_daily(low_sample_batter, date, plate_appearances: 4, at_bats: 4, hits: 4, doubles: 0, triples: 0, home_runs: 0, walks: 0)
    create_game(home_team: team, away_team: create_team, official_date: date)
    create_game(home_team: team, away_team: create_team, official_date: date)

    described_class.call(start_date: date, end_date: date)

    expect(PlayerMetricPercentile.joins(:league_metric_benchmark).where(
      player: low_sample_batter,
      league_metric_benchmarks: { metric_key: "ops" }
    )).to be_empty
  end

  it "previews an uncached player range without writing benchmark records" do
    counts = [ LeagueMetricBenchmark.count, PlayerMetricPercentile.count ]

    result = described_class.preview(player_id: batter_one.id, start_date: date, end_date: date)

    expect(result).to include(
      available: true,
      cached: false,
      source_start_date: date,
      source_end_date: date
    )
    ops = result.fetch(:metrics).find { |metric| metric[:metric_key] == "ops" }
    expect(ops).to include(
      raw_value: 1.35,
      position_key: "3B",
      percentile: 75.0,
      sample_size: 5,
      mlb_player_count: 2
    )
    expect(ops[:mlb_average]).to be_within(0.0001).of(0.9444)
    expect(ops[:position_average]).to be_within(0.0001).of(0.9444)
    expect([ LeagueMetricBenchmark.count, PlayerMetricPercentile.count ]).to eq(counts)
  end

  it "uses canonical season totals for full-season OPS" do
    {
      "plateAppearances" => 113,
      "atBats" => 100,
      "hits" => 30,
      "doubles" => 10,
      "triples" => 1,
      "homeRuns" => 5,
      "baseOnBalls" => 10,
      "strikeOuts" => 20,
      "hitByPitch" => 2,
      "sacFlies" => 1
    }.each do |name, value|
      stat_type = create_stat_type(attributes: { name: name, label: name })
      create_player_season_stat(
        player: batter_one,
        stat_type: stat_type,
        attributes: { season: date.year, value: value }
      )
    end

    result = described_class.preview(player_id: batter_one.id, start_date: Date.new(date.year, 1, 1), end_date: date)
    ops = result.fetch(:metrics).find { |metric| metric[:metric_key] == "ops" }
    strikeout_rate = result.fetch(:metrics).find { |metric| metric[:metric_key] == "batter_strikeout_percentage" }
    walk_rate = result.fetch(:metrics).find { |metric| metric[:metric_key] == "batter_walk_percentage" }

    expect(ops).to include(raw_value: 0.941681, sample_size: 113)
    expect(strikeout_rate).to include(raw_value: 17.699115, sample_size: 113)
    expect(walk_rate).to include(raw_value: 8.849558, sample_size: 113)
  end

  def common_daily(player, metric_date)
    {
      player: player,
      team: team,
      metric_date: metric_date,
      source_start_date: metric_date,
      source_end_date: metric_date,
      sample_size: 1,
      calculation_version: DailyAnalyticsRefresh::CALCULATION_VERSION,
      calculated_at: Time.current,
      source_name: "spec"
    }
  end

  def create_batting_daily(player, metric_date, metrics)
    PlayerBattingDaily.create!(common_daily(player, metric_date).merge(sample_size: metrics[:plate_appearances], metrics: metrics.stringify_keys))
  end

  def create_batter_split(player, metric_date, metrics)
    BatterSplitSummary.create!(common_daily(player, metric_date).merge(
      split_type: "home_away", split_value: "home", metrics: metrics.stringify_keys
    ))
  end

  def create_pitching_daily(player, metrics)
    PlayerPitchingDaily.create!(common_daily(player, date).merge(sample_size: metrics.fetch(:batters_faced, 5), metrics: metrics.stringify_keys))
  end

  def create_pitcher_split(player, metrics)
    PitcherSplitSummary.create!(common_daily(player, date).merge(
      split_type: "home_away", split_value: "home",
      metrics: metrics.merge(pitch_count: 10, velocity_sample_size: 10, spin_sample_size: 10).stringify_keys
    ))
  end

  def create_pitch_type(player, pitch_type, pitch_count)
    PitcherPitchTypeDaily.create!(common_daily(player, date).merge(
      pitch_type: pitch_type, sample_size: pitch_count, metrics: { "pitch_count" => pitch_count }
    ))
  end
end
