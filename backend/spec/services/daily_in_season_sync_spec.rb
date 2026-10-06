require "rails_helper"

RSpec.describe DailyInSeasonSync do
  let(:date) { Date.new(2026, 8, 13) }

  before do
    allow(MlbScheduleSync).to receive(:call).and_return(success_result)
    allow(MlbGameDetailsBatchSync).to receive(:call).and_return(success_result)
    allow(PitchDataBatchSync).to receive(:call).and_return(success_result)
    allow(PlayerStatsDownloader).to receive(:call).and_return(success_result(csv_data: "header\n"))
    allow(PlayerStatsImporter).to receive(:call).and_return(success_result)
    allow(MlbRosterSyncBoundary).to receive(:call).and_return(date)
    allow(MlbRosterBatchSync).to receive(:call).and_return(success_result)
    allow(MlbPlayerProfilesSync).to receive(:call).and_return(success_result)
    allow(MlbPlayerTeamHistoriesSync).to receive(:call).and_return(success_result)
    allow(ContextualBenchmarkRefresh).to receive(:call).and_return(success_result)
  end

  it "runs the daily in-season sequence in its required order" do
    result = described_class.call(start_date: date.to_s, end_date: date.to_s)

    expect(result).to include(success: true)
    expect(result.dig(:data, :stages).pluck(:name)).to eq([
      "schedules",
      "game details",
      "Statcast",
      "batting season stats",
      "pitching season stats",
      "40-man rosters",
      "missing player profiles",
      "contextual benchmarks"
    ])
    expect(MlbScheduleSync).to have_received(:call).with(
      start_date: date, end_date: date, game_types: MlbScheduleDownloader::DEFAULT_GAME_TYPES, sport_id: 1
    ).ordered
    expect(MlbGameDetailsBatchSync).to have_received(:call).with(start_date: date, end_date: date).ordered
    expect(PitchDataBatchSync).to have_received(:call).with(
      hash_including(game_types: MlbScheduleDownloader::DEFAULT_GAME_TYPES)
    ).ordered
    expect(PlayerStatsDownloader).to have_received(:call).with(category: "batting", start_year: 2026, end_year: 2026).ordered
    expect(PlayerStatsDownloader).to have_received(:call).with(category: "pitching", start_year: 2026, end_year: 2026).ordered
    expect(MlbRosterBatchSync).to have_received(:call).with(
      scope: "all", season: 2026, roster_type: "40Man", as_of: date
    ).ordered
    expect(MlbPlayerProfilesSync).to have_received(:call).with(only_missing: true).ordered
    expect(ContextualBenchmarkRefresh).to have_received(:call).with(start_date: date, end_date: date).ordered
  end

  it "stops when a stage fails" do
    allow(MlbGameDetailsBatchSync).to receive(:call).and_return(success: false, message: "game details unavailable", data: {})

    result = described_class.call(start_date: date, end_date: date)

    expect(result).to include(success: false, message: "game details failed: game details unavailable")
    expect(PitchDataBatchSync).not_to have_received(:call)
  end

  it "continues the remaining stages when Statcast fails" do
    allow(PitchDataBatchSync).to receive(:call).and_return(
      success: false,
      message: "Statcast provider unavailable",
      data: {}
    )

    result = described_class.call(start_date: date, end_date: date)

    expect(result).to include(
      success: false,
      message: "Completed remaining daily in-season refresh stages with failures: Statcast failed: Statcast provider unavailable"
    )
    expect(result.dig(:data, :stages).find { |stage| stage[:name] == "Statcast" }).to include(
      success: false,
      message: "Statcast failed: Statcast provider unavailable"
    )
    expect(PlayerStatsDownloader).to have_received(:call).twice
    expect(MlbRosterBatchSync).to have_received(:call)
    expect(MlbPlayerProfilesSync).to have_received(:call)
    expect(ContextualBenchmarkRefresh).to have_received(:call)
  end

  it "reports progress while each Statcast download chunk is running" do
    allow(PitchDataBatchSync).to receive(:call) do |progress_callback:, **_options|
      progress_callback.call(
        event: :download_started,
        chunk_start: date,
        chunk_end: date,
        chunk_index: 1,
        chunk_count: 1,
        game_count: 4
      )
      progress_callback.call(
        event: :download_finished,
        chunk_start: date,
        chunk_end: date,
        chunk_index: 1,
        chunk_count: 1,
        game_count: 4,
        row_count: 612,
        message: "Downloaded 612 pitch data rows from Baseball Savant"
      )
      success_result
    end

    expect { described_class.call(start_date: date, end_date: date) }
      .to output(/\[Statcast 1\/1\] Downloading 2026-08-13 through 2026-08-13 \(4 games\).*Downloaded 612 pitch rows/m).to_stdout
  end

  def success_result(data = {})
    { success: true, message: "ok", data: data }
  end
end
