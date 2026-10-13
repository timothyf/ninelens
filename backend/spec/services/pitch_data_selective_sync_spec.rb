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
    game.update!(pitch_data_complete_at: 1.day.ago, pitch_data_row_count: 120)
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

  it "uses the live feed when a live game has no historical pitch rows" do
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
end
