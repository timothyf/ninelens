require "rails_helper"

RSpec.describe GameBattedBallAnalysis do
  it "summarizes contact quality for each team and its leading hitters" do
    home_team = create_team(name: "Detroit Tigers", abbreviation: "DET")
    away_team = create_team(name: "Cleveland Guardians", abbreviation: "CLE")
    game = create_game(home_team: home_team, away_team: away_team)
    greene = create_player(team: home_team, attributes: { first_name: "Riley", last_name: "Greene" })
    carpenter = create_player(team: home_team, attributes: { first_name: "Kerry", last_name: "Carpenter" })
    kwan = create_player(team: away_team, attributes: { first_name: "Steven", last_name: "Kwan" })

    add_contact(game, greene, home_team, 1, launch_speed: 102.0, launch_angle: 28.0, bb_type: "fly_ball", expected_woba: 0.920, classification: 6)
    add_contact(game, greene, home_team, 2, launch_speed: 96.0, launch_angle: 14.0, bb_type: "line_drive", expected_woba: 0.580, classification: 5)
    add_contact(game, carpenter, home_team, 3, launch_speed: 88.0, launch_angle: -5.0, bb_type: "ground_ball", expected_woba: 0.210, classification: 2)
    add_contact(game, kwan, away_team, 4, launch_speed: 90.0, launch_angle: 52.0, bb_type: "popup", expected_woba: 0.080, classification: 3)

    result = described_class.call(game)
    detroit = result.find { |entry| entry.dig(:team, :abbreviation) == "DET" }
    cleveland = result.find { |entry| entry.dig(:team, :abbreviation) == "CLE" }

    expect(detroit).to include(
      home: true,
      batted_balls: 3,
      average_exit_velocity: 95.3,
      maximum_exit_velocity: 102.0,
      hard_hit_count: 2,
      hard_hit_percentage: 66.7,
      average_launch_angle: 12.3,
      estimated_woba: 0.57,
      barrel_count: 1,
      barrel_percentage: 33.3
    )
    expect(detroit.fetch(:distribution)).to eq(
      ground_ball: { count: 1, percentage: 33.3 },
      line_drive: { count: 1, percentage: 33.3 },
      fly_ball: { count: 1, percentage: 33.3 }
    )
    expect(detroit.fetch(:leaders).map { |entry| entry.dig(:player, :full_name) }).to eq([ "Riley Greene", "Kerry Carpenter" ])
    expect(detroit.dig(:leaders, 0)).to include(batted_balls: 2, average_exit_velocity: 99.0, barrel_count: 1)
    expect(cleveland.dig(:distribution, :fly_ball)).to eq(count: 1, percentage: 100.0)
  end

  def add_contact(game, player, team, number, launch_speed:, launch_angle:, bb_type:, expected_woba:, classification:)
    appearance = PlateAppearance.create!(
      game: game,
      batter: player,
      batting_team: team,
      at_bat_index: number - 1,
      plate_appearance_number: number,
      complete: true,
      source_name: "MLB Stats API",
      last_synced_at: Time.current
    )
    PitchDatum.create!(
      game: game,
      plate_appearance: appearance,
      game_pk: game.mlb_id,
      at_bat_number: number,
      pitch_number: 1,
      batter: player.mlb_id,
      description: "hit_into_play",
      launch_speed: launch_speed,
      launch_angle: launch_angle,
      bb_type: bb_type,
      estimated_woba_using_speedangle: expected_woba,
      launch_speed_angle: classification
    )
  end
end
