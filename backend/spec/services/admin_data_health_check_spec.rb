require "rails_helper"

RSpec.describe AdminDataHealthCheck do
  before { allow(MlbTotalsReconciliation).to receive(:call).and_return([]) }

  it "reports contextual completeness, linkage, profile, position, and analytics problems" do
    game = create_game(
      official_date: ApplicationCalendar.current_date - 1.day,
      status: "final",
      home_score: nil,
      away_score: 3,
      details_last_synced_at: Time.current
    )
    player = create_player
    PitchDatum.create!(
      game_pk: game.mlb_id,
      game_date: game.official_date,
      at_bat_number: 1,
      pitch_number: 1,
      raw_data: { "pitch" => 1 }
    )

    result = described_class.call

    expect(result).to include(status: "critical", calculation_version: DailyAnalyticsRefresh::CALCULATION_VERSION)
    expect(result.dig(:summary, :critical_count)).to be >= 3
    expect(result.dig(:summary, :warning_count)).to be >= 4
    expect(result[:checked_at]).to be_present

    checks = result.fetch(:checks).index_by { |check| check.fetch(:id) }
    expect(checks.dig("final_games_missing_scores", :affected_count)).to eq(1)
    expect(checks.dig("final_games_missing_pitch_data", :affected_count)).to eq(1)
    expect(checks.dig("synchronized_games_missing_batting_lines", :affected_count)).to eq(1)
    expect(checks.dig("synchronized_games_missing_pitching_lines", :affected_count)).to eq(1)
    expect(checks.dig("synchronized_games_missing_plate_appearances", :affected_count)).to eq(1)
    expect(checks.dig("pitches_missing_games", :affected_count)).to eq(1)
    expect(checks.dig("players_missing_profiles", :examples)).to include("#{player.full_name} · MLB #{player.mlb_id}")
    expect(checks.dig("players_missing_primary_positions", :affected_count)).to be >= 1
    expect(checks.dig("synchronized_dates_missing_analytics", :affected_count)).to eq(1)
  end

  it "flags past non-final games that already have player lines" do
    team = create_team
    opponent = create_team
    player = create_player(team: team)
    game = create_game(
      official_date: ApplicationCalendar.current_date - 1.day,
      status: "preview",
      home_team: opponent,
      away_team: team
    )
    GamePlayerBattingLine.create!(
      game: game,
      player: player,
      team: team,
      opponent_team: opponent,
      home: false,
      starter: true,
      plate_appearances: 4,
      at_bats: 4,
      hits: 1,
      source_name: "MLB Stats API",
      last_synced_at: Time.current
    )

    check = described_class.call.fetch(:checks).find { |entry| entry.fetch(:id) == "past_games_with_player_lines_not_final" }

    expect(check).to include(
      status: "critical",
      affected_count: 1,
      examples: include("MLB game #{game.mlb_id} · #{game.official_date.iso8601}")
    )
  end

  it "allows current-day non-final games with player lines" do
    team = create_team
    opponent = create_team
    player = create_player(team: team)
    game = create_game(
      official_date: ApplicationCalendar.current_date,
      status: "preview",
      home_team: opponent,
      away_team: team
    )
    GamePlayerBattingLine.create!(
      game: game,
      player: player,
      team: team,
      opponent_team: opponent,
      home: false,
      starter: true,
      plate_appearances: 4,
      at_bats: 4,
      hits: 1,
      source_name: "MLB Stats API",
      last_synced_at: Time.current
    )

    check = described_class.call.fetch(:checks).find { |entry| entry.fetch(:id) == "past_games_with_player_lines_not_final" }

    expect(check).to include(status: "healthy", affected_count: 0)
  end

  it "ignores canceled past games even when stored as final with stale player lines" do
    team = create_team
    opponent = create_team
    player = create_player(team: team)
    game = create_game(
      official_date: ApplicationCalendar.current_date - 1.day,
      status: "final",
      detailed_status: "Cancelled: Rain",
      home_score: nil,
      away_score: nil,
      home_team: opponent,
      away_team: team
    )
    GamePlayerBattingLine.create!(
      game: game,
      player: player,
      team: team,
      opponent_team: opponent,
      home: false,
      source_name: "MLB Stats API",
      last_synced_at: Time.current
    )

    checks = described_class.call.fetch(:checks).index_by { |entry| entry.fetch(:id) }

    expect(checks.fetch("final_games_missing_scores")).to include(status: "healthy", affected_count: 0)
    expect(checks.fetch("past_games_with_player_lines_not_final")).to include(status: "healthy", affected_count: 0)
  end

  it "does not require details or scores for future scheduled games" do
    create_game(official_date: ApplicationCalendar.current_date + 1.day, status: "scheduled")

    checks = described_class.call.fetch(:checks).index_by { |check| check.fetch(:id) }

    expect(checks.dig("final_games_missing_scores", :affected_count)).to eq(0)
    expect(checks.dig("final_games_missing_details", :affected_count)).to eq(0)
    expect(checks.dig("final_games_missing_pitch_data", :affected_count)).to eq(0)
  end
end
