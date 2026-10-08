require "rails_helper"

RSpec.describe DailyAnalyticsRefresh, type: :service do
  let(:date) { Date.new(2026, 7, 15) }
  let(:home_team) { create_team(mlb_id: 116, abbreviation: "DET") }
  let(:away_team) { create_team(mlb_id: 147, abbreviation: "NYY") }
  let(:game) do
    create_game(
      mlb_id: 823_443,
      official_date: date,
      scheduled_at: Time.find_zone!("America/New_York").local(date.year, date.month, date.day, 19, 5),
      home_team: home_team,
      away_team: away_team,
      home_score: 4,
      away_score: 2,
      status: "final"
    )
  end
  let(:batter) { create_player(team: away_team, attributes: { mlb_id: 592_450 }) }
  let(:pitcher) { create_player(team: home_team, attributes: { mlb_id: 669_373 }) }

  before do
    GamePlayerBattingLine.create!(
      game: game, player: batter, team: away_team, opponent_team: home_team,
      home: false, starter: true, plate_appearances: 4, at_bats: 3, runs: 1,
      hits: 2, doubles: 1, triples: 0, home_runs: 1, runs_batted_in: 2,
      walks: 1, strikeouts: 1, stolen_bases: 0, caught_stealing: 0,
      source_name: "MLB Stats API", last_synced_at: Time.current,
      raw_data: { "stats" => { "batting" => { "hitByPitch" => 1, "sacFlies" => 1 } } }
    )
    GamePlayerPitchingLine.create!(
      game: game, player: pitcher, team: home_team, opponent_team: away_team,
      home: true, starter: true, outs_recorded: 18, batters_faced: 24,
      hits: 4, runs: 2, earned_runs: 2, home_runs: 1, walks: 2,
      strikeouts: 8, pitches: 90, strikes: 60,
      source_name: "MLB Stats API", last_synced_at: Time.current
    )
    game.update!(
      boxscore_raw_data: {
        "teams" => {
          "home" => {
            "teamStats" => {
              "pitching" => {
                "inningsPitched" => "6.0",
                "battersFaced" => 24,
                "hits" => 4,
                "earnedRuns" => 1,
                "baseOnBalls" => 2,
                "strikeOuts" => 8
              }
            }
          },
          "away" => {
            "teamStats" => {
              "batting" => {
                "plateAppearances" => 6,
                "atBats" => 3,
                "runs" => 1,
                "hits" => 2,
                "doubles" => 1,
                "triples" => 0,
                "homeRuns" => 1,
                "baseOnBalls" => 1,
                "strikeOuts" => 1,
                "hitByPitch" => 1,
                "sacFlies" => 1
              }
            }
          }
        }
      }
    )

    create_pitch(pitch_number: 1, pitch_type: "FF", description: "called_strike", release_speed: 96.0)
    create_pitch(pitch_number: 2, pitch_type: "FF", description: "swinging_strike", release_speed: 98.0)
    create_pitch(pitch_number: 3, pitch_type: "SL", description: "hit_into_play", events: "home_run", release_speed: 86.0, launch_speed: 101.0, launch_speed_angle: 6, bat_speed: 75.6)
  end

  it "builds every summary family with calculation metadata" do
    result = described_class.call(start_date: date, end_date: date)

    expect(result).to include(success: true)
    expect(result.dig(:data, :benchmark_refreshes, 0, :success)).to be(true)
    expect(result.dig(:data, :row_counts)).to include(
      "player_batting_daily" => 1,
      "player_pitching_daily" => 1,
      "pitcher_pitch_type_daily" => 2,
      "batter_split_summaries" => 5,
      "pitcher_split_summaries" => 5,
      "team_daily_metrics" => 2
    )

    batting = PlayerBattingDaily.find_by!(player: batter, metric_date: date)
    expect(batting).to have_attributes(
        calculation_version: DailyAnalyticsRefresh::CALCULATION_VERSION,
      source_start_date: date,
      source_end_date: date,
      sample_size: 4
    )
    expect(batting.calculated_at).to be_present
    expect(batting.metrics).to include(
      "hits" => 2,
      "home_runs" => 1,
      "hit_by_pitch" => 1,
      "sacrifice_flies" => 1,
      "batting_average" => 0.6667,
      "slugging_percentage" => 2.0
    )

    fastball = PitcherPitchTypeDaily.find_by!(player: pitcher, metric_date: date, pitch_type: "FF")
    expect(fastball.sample_size).to eq(2)
    expect(fastball.metrics).to include(
      "usage_percentage" => 66.67,
      "average_velocity" => 97.0,
      "whiffs" => 1
    )
    expect(BatterSplitSummary.find_by!(player: batter, split_type: "pitcher_hand", split_value: "R").metrics)
      .to include(
        "pitches_seen" => 3,
        "plate_appearances" => 1,
        "barrel_count" => 1,
        "barrel_percentage" => 100.0,
        "average_bat_speed" => 75.6
      )
    expect(BatterSplitSummary.find_by!(player: batter, split_type: "day_night", split_value: "night").metrics)
      .to include("pitches_seen" => 3)
    expect(PitcherSplitSummary.find_by!(player: pitcher, split_type: "day_night", split_value: "night").metrics)
      .to include("pitch_count" => 3)
    expect(TeamDailyMetric.find_by!(team: home_team).metrics).to include(
      "wins" => 1,
      "runs_scored" => 4,
      "pitching_batters_faced" => 24,
      "pitching_earned_runs" => 1,
      "pitching_strikeouts" => 8,
      "pitching_walks" => 2,
      "pitching_saves" => 0,
      "pitching_quality_starts" => 1
    )
    expect(TeamDailyMetric.find_by!(team: away_team).metrics).to include(
      "hit_by_pitch" => 1,
      "sacrifice_flies" => 1,
      "on_base_percentage" => 0.6667,
      "on_base_percentage_is_approximate" => false,
      "ops" => 2.6667
    )
  end

  it "excludes foul-ball contact from batted-ball metrics" do
    create_pitch(
      pitch_number: 4,
      pitch_type: "FF",
      description: "foul",
      events: "field_out",
      launch_speed: 45.0,
      launch_angle: -30.0
    )

    described_class.call(start_date: date, end_date: date, refresh_contextual_benchmarks: false)

    metrics = BatterSplitSummary.find_by!(player: batter, split_type: "home_away", split_value: "away").metrics
    expect(metrics).to include(
      "pitches_seen" => 4,
      "batted_balls" => 1,
      "exit_velocity_sample_size" => 1,
      "average_exit_velocity" => 101.0,
      "hard_hit_percentage" => 100.0
    )
  end

  it "includes finalized postseason games in daily analytics" do
    game.update!(game_type: "D")

    result = described_class.call(start_date: date, end_date: date, refresh_contextual_benchmarks: false)

    expect(result.dig(:data, :row_counts, "team_daily_metrics")).to eq(2)
    expect(TeamDailyMetric.where(metric_date: date).pluck(:team_id)).to contain_exactly(home_team.id, away_team.id)
  end

  it "recognizes title-cased MLB live-feed swing descriptions" do
    create_pitch(pitch_number: 4, pitch_type: "FF", description: "Swinging Strike", zone: 11)
    create_pitch(pitch_number: 5, pitch_type: "FF", description: "In play, no out", zone: 12)

    described_class.call(start_date: date, end_date: date, refresh_contextual_benchmarks: false)

    metrics = BatterSplitSummary.find_by!(player: batter, split_type: "home_away", split_value: "away").metrics
    expect(metrics).to include("chase_opportunities" => 2, "chases" => 2, "chase_percentage" => 100.0)
  end

  it "counts foul tips as whiffs" do
    create_pitch(pitch_number: 4, pitch_type: "FF", description: "foul_tip", zone: 5)

    described_class.call(start_date: date, end_date: date, refresh_contextual_benchmarks: false)

    metrics = BatterSplitSummary.find_by!(player: batter, split_type: "home_away", split_value: "away").metrics
    expect(metrics).to include("swings" => 3, "whiffs" => 2, "whiff_percentage" => 66.67)
  end

  it "replaces the same version idempotently while preserving other calculation versions" do
    described_class.call(dates: [ date ], calculation_version: "1.0.0")
    first_count = summary_count
    described_class.call(dates: [ date ], calculation_version: "1.0.0")

    expect(summary_count).to eq(first_count)

    described_class.call(dates: [ date ], calculation_version: "2.0.0")

    expect(summary_count).to eq(first_count * 2)
    expect(PlayerBattingDaily.where(metric_date: date).pluck(:calculation_version)).to contain_exactly("1.0.0", "2.0.0")
  end

  it "rejects reversed date ranges" do
    result = described_class.call(start_date: "2026-07-16", end_date: "2026-07-15")

    expect(result).to include(success: false, message: "End date must be on or after start date")
  end

  it "can refresh daily summaries without contextual benchmark rebuild" do
    result = described_class.call(start_date: date, end_date: date, refresh_contextual_benchmarks: false)

    expect(result).to include(success: true)
    expect(result.dig(:data, :contextual_benchmarks_refreshed)).to be(false)
    expect(result.dig(:data, :benchmark_refreshes)).to eq([])
  end

  it "does not count a preview with placeholder scores as a played game" do
    preview_home = create_team(mlb_id: 108, abbreviation: "LAA")
    preview_away = create_team(mlb_id: 117, abbreviation: "HOU")
    create_game(
      mlb_id: 823_444,
      official_date: date,
      home_team: preview_home,
      away_team: preview_away,
      home_score: 0,
      away_score: 0,
      status: "preview"
    )

    described_class.call(start_date: date, end_date: date, refresh_contextual_benchmarks: false)

    expect(TeamDailyMetric.where(metric_date: date).pluck(:team_id)).to contain_exactly(home_team.id, away_team.id)
  end

  def create_pitch(attributes)
    PitchDatum.create!(
      {
        game: game,
        game_pk: game.mlb_id,
        game_date: date,
        at_bat_number: 1,
        pitcher: pitcher.mlb_id,
        batter: batter.mlb_id,
        stand: "R",
        p_throws: "R",
        inning_topbot: "Top",
        pitch_name: attributes[:pitch_type] == "FF" ? "4-Seam Fastball" : "Slider",
        raw_data: { "source" => "spec" }
      }.merge(attributes)
    )
  end

  def summary_count
    described_class::SUMMARY_MODELS.sum(&:count)
  end
end
