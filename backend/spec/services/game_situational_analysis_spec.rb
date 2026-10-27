require "rails_helper"

RSpec.describe GameSituationalAnalysis do
  it "summarizes important situations, batting-order trips, and the turning point" do
    home_team = create_team(name: "Detroit Tigers", abbreviation: "DET")
    away_team = create_team(name: "Cleveland Guardians", abbreviation: "CLE")
    game = create_game(home_team: home_team, away_team: away_team, home_score: 4, away_score: 1)
    leadoff = create_player(team: home_team, attributes: { first_name: "Riley", last_name: "Greene" })
    pinch_hitter = create_player(team: home_team, attributes: { first_name: "Kerry", last_name: "Carpenter" })
    away_hitter = create_player(team: away_team, attributes: { first_name: "Steven", last_name: "Kwan" })
    add_batting_line(game, leadoff, home_team, away_team, home: true, starter: true, batting_order: 100)
    add_batting_line(game, pinch_hitter, home_team, away_team, home: true, starter: false, batting_order: 901)
    add_batting_line(game, away_hitter, away_team, home_team, home: false, starter: true, batting_order: 100)

    add_appearance(game, away_hitter, away_team, 1, event_type: "single", inning: 1, half: "top",
      away_score: 1, home_score: 0, outs: 2, on_2b: 9001, delta_wpa: -0.45, prior_appearances: 0, rbi: 1)
    add_appearance(game, leadoff, home_team, 2, event_type: "walk", inning: 1, half: "bottom",
      away_score: 1, home_score: 0, outs: 0, delta_wpa: 0.02, prior_appearances: 0)
    turning_point = add_appearance(game, pinch_hitter, home_team, 3, event_type: "home_run", inning: 8, half: "bottom",
      away_score: 1, home_score: 4, outs: 2, on_1b: 9002, on_2b: 9003, on_3b: 9004,
      delta_wpa: 0.35, prior_appearances: 0, rbi: 4, description: "Kerry Carpenter hits a grand slam.")
    add_appearance(game, leadoff, home_team, 4, event_type: "strikeout", inning: 8, half: "bottom",
      away_score: 1, home_score: 4, outs: 2, delta_wpa: -0.05, prior_appearances: 1)

    result = described_class.call(game)
    detroit = result.fetch(:teams).find { |entry| entry.dig(:team, :abbreviation) == "DET" }

    expect(detroit.dig(:situations, :runners_in_scoring_position)).to include(
      plate_appearances: 1, at_bats: 1, hits: 1, runs_batted_in: 4, batting_average: 1.0
    )
    expect(detroit.dig(:situations, :two_outs, :plate_appearances)).to eq(2)
    expect(detroit.dig(:situations, :bases_loaded, :hits)).to eq(1)
    expect(detroit.dig(:situations, :pinch_hitters, :hits)).to eq(1)
    expect(detroit.dig(:situations, :high_leverage, :plate_appearances)).to eq(1)
    expect(detroit.dig(:situations, :leadoff_hitters)).to include(
      plate_appearances: 2, at_bats: 1, hits: 0, walks: 1, strikeouts: 1, on_base_percentage: 0.5
    )
    expect(detroit.fetch(:batting_order_trips).map { |trip| trip.fetch(:trip) }).to eq([ 1, 2 ])
    expect(detroit.dig(:batting_order_trips, 0)).to include(plate_appearances: 2, hits: 1, walks: 1)
    expect(result.fetch(:turning_point)).to include(
      type: "win_probability",
      inning_label: "Bottom 8th",
      description: turning_point.description,
      home_win_probability_change: 0.35,
      benefiting_team: include(abbreviation: "DET")
    )
  end

  it "uses a scoring play by the eventual winner when WPA data is unavailable" do
    home_team = create_team(name: "Oakland Athletics", abbreviation: "OAK")
    away_team = create_team(name: "Detroit Tigers", abbreviation: "DET")
    game = create_game(home_team: home_team, away_team: away_team, home_score: 6, away_score: 8)
    detroit_hitter = create_player(team: away_team, attributes: { first_name: "Colt", last_name: "Keith" })
    oakland_hitter = create_player(team: home_team, attributes: { first_name: "Henry", last_name: "Bolte" })

    detroit_play = add_appearance(game, detroit_hitter, away_team, 1, event_type: "double", inning: 5, half: "top",
      away_score: 2, home_score: 0, outs: 1, delta_wpa: nil, prior_appearances: 0, rbi: 2,
      description: "Colt Keith doubles. Two runs score.")
    add_appearance(game, oakland_hitter, home_team, 2, event_type: "home_run", inning: 8, half: "bottom",
      away_score: 8, home_score: 5, outs: 1, delta_wpa: nil, prior_appearances: 0, rbi: 3,
      description: "Henry Bolte homers. Three runs score.")

    expect(described_class.call(game).fetch(:turning_point)).to include(
      type: "scoring_play",
      description: detroit_play.description,
      batting_team: include(abbreviation: "DET"),
      benefiting_team: include(abbreviation: "DET")
    )
  end

  def add_batting_line(game, player, team, opponent, home:, starter:, batting_order:)
    GamePlayerBattingLine.create!(
      game: game, player: player, team: team, opponent_team: opponent, home: home,
      starter: starter, batting_order: batting_order, source_name: "MLB Stats API", last_synced_at: Time.current
    )
  end

  def add_appearance(game, player, team, number, event_type:, inning:, half:, away_score:, home_score:,
    outs:, delta_wpa:, prior_appearances:, rbi: 0, description: nil, on_1b: nil, on_2b: nil, on_3b: nil)
    appearance = PlateAppearance.create!(
      game: game, batter: player, batting_team: team, at_bat_index: number - 1,
      plate_appearance_number: number, inning: inning, half_inning: half,
      event: event_type.humanize, event_type: event_type, description: description || event_type.humanize,
      runs_batted_in: rbi, away_score: away_score, home_score: home_score, complete: true,
      source_name: "MLB Stats API", last_synced_at: Time.current
    )
    PitchDatum.create!(
      game: game, plate_appearance: appearance, game_pk: game.mlb_id, at_bat_number: number,
      pitch_number: 1, batter: player.mlb_id, outs_when_up: outs, on_1b: on_1b, on_2b: on_2b, on_3b: on_3b,
      delta_home_win_exp: delta_wpa, n_priorpa_thisgame_player_at_bat: prior_appearances
    )
    appearance
  end
end
