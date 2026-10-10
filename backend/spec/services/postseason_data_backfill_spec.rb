require "rails_helper"

RSpec.describe PostseasonDataBackfill do
  it "syncs each season's schedule and only downloads missing final postseason game details" do
    schedule = create_schedule(season: 2025)
    team = create_team
    opponent = create_team
    complete_game = create_game(
      schedule: schedule, home_team: team, away_team: opponent, game_type: "D", status: "final",
      official_date: Date.new(2025, 10, 5), details_last_synced_at: Time.current
    )
    missing_game = create_game(
      schedule: schedule, home_team: team, away_team: opponent, game_type: "W", status: "final",
      official_date: Date.new(2025, 10, 25)
    )
    player = create_player(team: team)
    GamePlayerBattingLine.create!(
      game: complete_game, player: player, team: team, opponent_team: opponent, home: true,
      source_name: "spec", last_synced_at: Time.current
    )
    GamePlayerPitchingLine.create!(
      game: complete_game, player: player, team: team, opponent_team: opponent, home: true,
      source_name: "spec", last_synced_at: Time.current
    )
    allow(MlbScheduleSync).to receive(:call).and_return(
      success: true, message: "ok", data: { created_game_count: 0, updated_game_count: 2 }
    )
    allow(MlbGameDetailsSync).to receive(:call).with(game: missing_game).and_return(
      success: true,
      message: "ok",
      data: { batting_line_count: 18, pitching_line_count: 8, created_player_count: 4 }
    )

    result = described_class.call(start_year: 2025, end_year: 2025)

    expect(result[:success]).to be(true)
    expect(MlbScheduleSync).to have_received(:call).with(
      start_date: Date.new(2025, 9, 20), end_date: Date.new(2025, 11, 15),
      game_types: "F,D,L,W", sport_id: 1
    )
    expect(MlbGameDetailsSync).to have_received(:call).once
    expect(result[:data]).to include(
      stored_game_count: 2, target_game_count: 1, synchronized_game_count: 1,
      batting_line_count: 18, pitching_line_count: 8, created_player_count: 4
    )
  end

  it "reports stored gaps without downloading data in dry-run mode" do
    schedule = create_schedule(season: 2024)
    create_game(schedule: schedule, game_type: "F", status: "final", official_date: Date.new(2024, 10, 1))
    allow(MlbScheduleSync).to receive(:call)
    allow(MlbGameDetailsSync).to receive(:call)

    result = described_class.call(start_year: 2024, end_year: 2024, dry_run: true)

    expect(result[:success]).to be(true)
    expect(result[:data]).to include(stored_game_count: 1, target_game_count: 1, synchronized_game_count: 0, dry_run: true)
    expect(MlbScheduleSync).not_to have_received(:call)
    expect(MlbGameDetailsSync).not_to have_received(:call)
  end
end
