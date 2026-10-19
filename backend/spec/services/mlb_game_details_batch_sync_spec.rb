require "rails_helper"

RSpec.describe MlbGameDetailsBatchSync do
  it "continues after an unavailable game and reports the failure" do
    first = create_game(mlb_id: 800_001, official_date: Date.new(2026, 7, 15))
    second = create_game(mlb_id: 800_002, official_date: Date.new(2026, 7, 15))
    allow(DailyAnalyticsRefresh).to receive(:call).and_return(success: true, message: "ok", data: {})
    allow(MlbGameDetailsSync).to receive(:call).with(game: first).and_return(
      success: true,
      message: "Synchronized",
      data: { batting_line_count: 2, plate_appearance_count: 10 }
    )
    allow(MlbGameDetailsSync).to receive(:call).with(game: second).and_return(
      success: false,
      message: "HTTP 404: Not Found",
      data: {}
    )

    result = described_class.call(start_date: "2026-07-15", end_date: "2026-07-15", worker_count: 1)

    expect(result[:success]).to be(true)
    expect(result.dig(:data, :synchronized_game_count)).to eq(1)
    expect(result.dig(:data, :failed_game_count)).to eq(1)
    expect(result.dig(:data, :batting_line_count)).to eq(2)
    expect(result.dig(:data, :errors)).to include(hash_including(mlb_id: 800_002, message: "HTTP 404: Not Found"))
    expect(result.dig(:data, :analytics_refresh, :success)).to be(true)
    expect(DailyAnalyticsRefresh).to have_received(:call).with(dates: [ Date.new(2026, 7, 15) ], refresh_contextual_benchmarks: false)
    expect(result.dig(:data, :worker_pool_summary)).to include(
      configured_workers: 1,
      active_workers: 1,
      games_enqueued: 2,
      games_dequeued: 2,
      games_finalized: 2,
      worker_error_count: 0
    )
  end

  it "rejects a reversed date range" do
    result = described_class.call(start_date: "2026-07-16", end_date: "2026-07-15", worker_count: 1)

    expect(result).to include(success: false, message: "End date must be on or after start date")
  end

  it "does not synchronize cancelled or unplayed if-necessary games for a date range" do
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
        home_score: 5,
        away_score: 3,
        game_type: "D"
      )
    end
    played_game = create_game(
      mlb_id: 849_805,
      schedule: schedule,
      official_date: Date.new(2026, 10, 18),
      home_team: home_team,
      away_team: away_team,
      status: "final",
      home_score: 5,
      away_score: 3,
      game_type: "D"
    )
    create_game(
      mlb_id: 849_806,
      schedule: schedule,
      official_date: Date.new(2026, 10, 18),
      home_team: away_team,
      away_team: home_team,
      status: "scheduled",
      game_type: "D",
      raw_data: { "ifNecessary" => "Y", "seriesGameNumber" => 6 }
    )
    create_game(
      mlb_id: 849_807,
      schedule: schedule,
      official_date: Date.new(2026, 10, 18),
      home_team: home_team,
      away_team: away_team,
      status: "cancelled",
      detailed_status: "Cancelled"
    )
    allow(DailyAnalyticsRefresh).to receive(:call).and_return(success: true, message: "ok", data: {})
    allow(MlbGameDetailsSync).to receive(:call).with(game: played_game).and_return(
      success: true,
      message: "Synchronized",
      data: {}
    )

    result = described_class.call(start_date: "2026-10-18", end_date: "2026-10-18", worker_count: 1)

    expect(result).to include(success: true, message: "Synchronized details for 1 of 1 MLB games")
    expect(result.dig(:data, :game_count)).to eq(1)
    expect(MlbGameDetailsSync).to have_received(:call).with(game: played_game)
  end

  it "reports progress and stops safely between games when cancellation is requested" do
    first = create_game(mlb_id: 800_011, official_date: Date.new(2026, 7, 15))
    second = create_game(mlb_id: 800_012, official_date: Date.new(2026, 7, 15))
    allow(DailyAnalyticsRefresh).to receive(:call).and_return(success: true, message: "ok", data: {})
    tracker = instance_double(MlbGameDetailsProgressTracker)
    allow(tracker).to receive(:start!)
    allow(tracker).to receive(:cancel_requested?).and_return(false, true, true)
    allow(tracker).to receive(:game_started!)
    allow(tracker).to receive(:game_finished!)
    allow(MlbGameDetailsSync).to receive(:call).with(game: first).and_return(success: true, message: "Synchronized", data: {})

    result = described_class.call(start_date: "2026-07-15", end_date: "2026-07-15", progress_tracker: tracker, worker_count: 1)

    expect(result).to include(success: true, message: "Cancelled after processing 1 of 2 MLB games")
    expect(result.dig(:data, :cancelled)).to be(true)
    expect(tracker).to have_received(:start!).with(total: 2)
    expect(tracker).to have_received(:game_started!).with(first)
    expect(tracker).to have_received(:game_finished!).with(game: first, success: true, message: "Synchronized")
    expect(MlbGameDetailsSync).not_to have_received(:call).with(game: second)
    expect(DailyAnalyticsRefresh).to have_received(:call).with(dates: [ Date.new(2026, 7, 15) ], refresh_contextual_benchmarks: false)
  end

  it "rejects an out-of-range worker count" do
    result = described_class.call(start_date: "2026-07-15", end_date: "2026-07-15", worker_count: 10)

    expect(result).to include(success: false, message: "Worker count must be between 1 and 6")
  end

  it "records a timeout failure and continues with subsequent games" do
    first = create_game(mlb_id: 800_021, official_date: Date.new(2026, 7, 15))
    second = create_game(mlb_id: 800_022, official_date: Date.new(2026, 7, 15))
    allow(DailyAnalyticsRefresh).to receive(:call).and_return(success: true, message: "ok", data: {})
    allow(MlbGameDetailsSync).to receive(:call).with(game: first).and_raise(Timeout::Error)
    allow(MlbGameDetailsSync).to receive(:call).with(game: second).and_return(success: true, message: "Synchronized", data: {})

    result = described_class.call(start_date: "2026-07-15", end_date: "2026-07-15", worker_count: 1)

    expect(result[:success]).to be(true)
    expect(result.dig(:data, :synchronized_game_count)).to eq(1)
    expect(result.dig(:data, :failed_game_count)).to eq(1)
    expect(result.dig(:data, :errors)).to include(
      hash_including(mlb_id: 800_021, message: "Game details sync timed out after 60 seconds", errors: ["Timeout::Error"])
    )
  end
end
