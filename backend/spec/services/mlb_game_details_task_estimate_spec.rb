require "rails_helper"

RSpec.describe MlbGameDetailsTaskEstimate do
  it "uses the exact stored-game count and completed sync timing" do
    25.times do |index|
      create_game(mlb_id: 820_000 + index, official_date: Date.new(2026, 7, index.even? ? 1 : 2))
    end
    started_at = Time.zone.parse("2026-07-15 10:00:00")
    AdminTaskRun.create!(
      task_name: "mlb_game_details_sync",
      status: "completed",
      total_items: 25,
      completed_items: 25,
      started_at: started_at,
      finished_at: started_at + 1326.seconds
    )

    estimate = described_class.call(start_date: "2026-07-01", end_date: "2026-07-02")

    expect(estimate).to include(
      game_count: 25,
      estimated_seconds: 1326,
      low_estimated_seconds: 1061,
      high_estimated_seconds: 1724,
      seconds_per_game: 53.0,
      timing_sample_game_count: 25,
      timing_sample_run_count: 1,
      estimate_source: "historical"
    )
  end

  it "uses a conservative fifty-second estimate until timing history exists" do
    create_game(mlb_id: 820_100, official_date: Date.new(2026, 7, 1))

    estimate = described_class.call(start_date: "2026-07-01", end_date: "2026-07-01")

    expect(estimate).to include(
      game_count: 1,
      estimated_seconds: 50,
      timing_sample_game_count: 0,
      timing_sample_run_count: 0,
      estimate_source: "conservative_default"
    )
  end

  it "excludes cancelled and unplayed if-necessary games from the estimate" do
    home_team = create_team
    away_team = create_team
    schedule = create_schedule(
      season: 2026,
      schedule_type: "D",
      start_date: Date.new(2026, 10, 1),
      end_date: Date.new(2026, 10, 20)
    )
    3.times do |index|
      create_game(
        schedule: schedule,
        official_date: Date.new(2026, 10, 15) + index.days,
        home_team: home_team,
        away_team: away_team,
        status: "final",
        home_score: 4,
        away_score: 2,
        game_type: "D"
      )
    end
    create_game(
      mlb_id: 820_200,
      schedule: schedule,
      official_date: Date.new(2026, 10, 18),
      home_team: home_team,
      away_team: away_team,
      status: "final",
      home_score: 4,
      away_score: 2,
      game_type: "D"
    )
    create_game(
      mlb_id: 820_201,
      schedule: schedule,
      official_date: Date.new(2026, 10, 18),
      home_team: away_team,
      away_team: home_team,
      status: "scheduled",
      game_type: "D",
      raw_data: { "ifNecessary" => "Y", "seriesGameNumber" => 6 }
    )
    create_game(
      mlb_id: 820_202,
      schedule: schedule,
      official_date: Date.new(2026, 10, 18),
      home_team: home_team,
      away_team: away_team,
      status: "cancelled",
      detailed_status: "Cancelled"
    )

    estimate = described_class.call(start_date: "2026-10-18", end_date: "2026-10-18")

    expect(estimate[:game_count]).to eq(1)
  end
end
