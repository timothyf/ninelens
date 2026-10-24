require "rails_helper"

RSpec.describe "selective Statcast pitch synchronization" do
  def game_for(date:, mlb_id:)
    schedule = create_schedule(season: date.year)
    create_game(schedule: schedule, official_date: date, mlb_id: mlb_id, game_type: "R")
  end

  it "excludes completed games from the estimate and does not download an all-complete range" do
    game = game_for(date: Date.new(2026, 7, 1), mlb_id: 700_001)
    game.update!(pitch_data_complete_at: Time.current, pitch_data_row_count: 150)

    estimate = PitchDataSyncTaskEstimate.call(start_date: "2026-07-01", end_date: "2026-07-01", game_types: "R", chunk_days: 1)

    expect(estimate).to include(game_count: 0, already_complete_game_count: 1)
    expect(PitchDataDownloader).not_to receive(:call)

    result = PitchDataBatchSync.call(start_date: "2026-07-01", end_date: "2026-07-01", game_types: "R", chunk_days: 1)

    expect(result).to include(success: true)
    expect(result.dig(:data, :already_complete_game_count)).to eq(1)
    expect(result.dig(:data, :downloaded_count)).to eq(0)
  end

  it "includes completed games when replacement is explicitly requested" do
    game = game_for(date: Date.new(2026, 7, 2), mlb_id: 700_002)
    game.update!(status: "final", pitch_data_complete_at: 1.day.ago, pitch_data_row_count: 120)
    PitchDatum.create!(game: game, game_pk: game.mlb_id, at_bat_number: 1, pitch_number: 1, raw_data: { "old" => true })
    allow(PitchDataDownloader).to receive(:call).and_return(
      success: true,
      data: { rows: [ { "game_pk" => game.mlb_id.to_s, "at_bat_number" => "2", "pitch_number" => "1", "game_date" => "2026-07-02" } ] }
    )

    progress_events = []
    result = PitchDataBatchSync.call(
      start_date: "2026-07-02",
      end_date: "2026-07-02",
      game_types: "R",
      chunk_days: 1,
      replace_existing: true,
      progress_callback: ->(**event) { progress_events << event }
    )

    expect(result).to include(success: true)
    expect(progress_events).to include(
      hash_including(event: :download_started, chunk_index: 1, chunk_count: 1, game_count: 1),
      hash_including(event: :download_finished, row_count: 1)
    )
    expect(PitchDatum.where(game_id: game.id).pluck(:at_bat_number, :pitch_number)).to eq([ [ 2, 1 ] ])
    expect(game.reload.pitch_data_complete_at).to be_present
    expect(game.pitch_data_row_count).to eq(1)
  end

  it "uses the MLB feed when a final game has no Baseball Savant rows" do
    game = game_for(date: Date.new(2026, 7, 3), mlb_id: 700_003)
    game.update!(status: "final")
    allow(PitchDataDownloader).to receive(:call).and_return(success: false, message: "No pitch data rows returned from Baseball Savant", data: {})
    allow(MlbLivePitchDataDownloader).to receive(:call).with(game: game).and_return(
      success: true,
      rows: [
        {
          "game_pk" => game.mlb_id.to_s,
          "game_date" => game.official_date.iso8601,
          "at_bat_number" => "1",
          "pitch_number" => "1",
          "pitch_type" => "FF"
        }
      ]
    )

    result = PitchDataBatchSync.call(start_date: "2026-07-03", end_date: "2026-07-03", game_types: "R", chunk_days: 1)

    expect(result).to include(success: true)
    expect(PitchDatum.where(game_id: game.id).pluck(:game_pk, :pitch_type)).to eq([[ game.mlb_id, "FF" ]])
    expect(MlbLivePitchDataDownloader).to have_received(:call).with(game: game)
  end

  it "keeps an in-progress game eligible for repeated pitch imports until it is final" do
    game = game_for(date: Date.new(2026, 7, 3), mlb_id: 700_006)
    game.update!(status: "live")
    allow(PitchDataDownloader).to receive(:call) do
      message = game.reload.status == "live" ? "Failed to download pitch data: HTTP 403: Forbidden" : "No pitch data rows returned from Baseball Savant"
      { success: false, message: message, data: {} }
    end
    allow(DailyAnalyticsRefresh).to receive(:call).and_return(success: true)
    live_rows = [ { "game_pk" => game.mlb_id.to_s, "game_date" => "2026-07-03", "at_bat_number" => "1", "pitch_number" => "1", "pitch_type" => "FF" } ]
    allow(MlbLivePitchDataDownloader).to receive(:call).with(game: game) { { success: true, rows: live_rows } }

    first_result = PitchDataBatchSync.call(start_date: "2026-07-03", end_date: "2026-07-03", game_types: "R", chunk_days: 1)

    expect(first_result[:success]).to be(true)
    expect(game.reload.pitch_data_complete_at).to be_nil
    expect(game.pitch_data_row_count).to eq(1)
    expect(PitchDataSyncTaskEstimate.call(start_date: "2026-07-03", end_date: "2026-07-03", game_types: "R", chunk_days: 1)[:game_count]).to eq(1)

    live_rows = [
      live_rows.first.merge("pitch_type" => "SI"),
      { "game_pk" => game.mlb_id.to_s, "game_date" => "2026-07-03", "at_bat_number" => "1", "pitch_number" => "2", "pitch_type" => "FF" }
    ]
    second_result = PitchDataBatchSync.call(start_date: "2026-07-03", end_date: "2026-07-03", game_types: "R", chunk_days: 1)

    expect(second_result[:success]).to be(true)
    expect(PitchDatum.where(game_id: game.id).order(:pitch_number).pluck(:pitch_type)).to eq(%w[SI FF])
    expect(game.reload.pitch_data_complete_at).to be_nil
    expect(game.pitch_data_row_count).to eq(2)

    game.update!(status: "final")
    final_result = PitchDataBatchSync.call(start_date: "2026-07-03", end_date: "2026-07-03", game_types: "R", chunk_days: 1)

    expect(final_result[:success]).to be(true)
    expect(game.reload.pitch_data_complete_at).to be_present
    expect(PitchDataSyncTaskEstimate.call(start_date: "2026-07-03", end_date: "2026-07-03", game_types: "R", chunk_days: 1)[:game_count]).to eq(0)
  end

  it "excludes cancelled games from estimates and replacement syncs" do
    cancelled = game_for(date: Date.new(2026, 7, 4), mlb_id: 700_004)
    canceled = game_for(date: Date.new(2026, 7, 4), mlb_id: 700_005)
    cancelled.update!(status: "final", detailed_status: "Cancelled: Rain")
    canceled.update!(status: "canceled", detailed_status: "Game Canceled")

    estimate = PitchDataSyncTaskEstimate.call(
      start_date: "2026-07-04",
      end_date: "2026-07-04",
      game_types: "R",
      chunk_days: 1,
      replace_existing: true
    )

    expect(estimate).to include(game_count: 0, already_complete_game_count: 0)
    expect(PitchDataDownloader).not_to receive(:call)
    expect(MlbLivePitchDataDownloader).not_to receive(:call)

    result = PitchDataBatchSync.call(
      start_date: "2026-07-04",
      end_date: "2026-07-04",
      game_types: "R",
      chunk_days: 1,
      replace_existing: true
    )

    expect(result).to include(success: true)
    expect(result.dig(:data, :game_count)).to eq(0)
    expect(result.dig(:data, :errors)).to be_empty
  end

  it "excludes unplayed if-necessary games after a postseason series is clinched" do
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
      schedule: schedule,
      official_date: Date.new(2026, 10, 18),
      home_team: away_team,
      away_team: home_team,
      game_type: "D",
      status: "scheduled",
      raw_data: { "ifNecessary" => "Y" }
    )

    estimate = PitchDataSyncTaskEstimate.call(
      start_date: "2026-10-18",
      end_date: "2026-10-18",
      game_types: "D",
      chunk_days: 1,
      replace_existing: true
    )

    expect(estimate).to include(game_count: 0, already_complete_game_count: 0)
    expect(PitchDataDownloader).not_to receive(:call)

    result = PitchDataBatchSync.call(
      start_date: "2026-10-18",
      end_date: "2026-10-18",
      game_types: "D",
      chunk_days: 1,
      replace_existing: true
    )

    expect(result).to include(success: true)
    expect(result.dig(:data, :game_count)).to eq(0)
  end
end
