require "rails_helper"

RSpec.describe OpponentPreparationQuery do
  it "builds opponent form and evidence-backed probable-starter scouting" do
    team = create_team(name: "Detroit Tigers", abbreviation: "DET")
    opponent = create_team(name: "Cleveland Guardians", abbreviation: "CLE")
    pitcher = create_player(team: opponent, attributes: { mlb_id: 999_001, first_name: "Test", last_name: "Starter" })
    schedule = create_schedule(season: Date.current.year)
    historical_game = create_game(
      schedule: schedule,
      home_team: opponent,
      away_team: team,
      official_date: Date.current - 1.day,
      status: "final",
      home_score: 4,
      away_score: 2
    )
    upcoming_game = create_game(
      schedule: schedule,
      home_team: team,
      away_team: opponent,
      official_date: Date.current + 1.day,
      status: "scheduled",
      away_probable_pitcher: pitcher
    )
    appearance = PlateAppearance.create!(
      game: historical_game,
      pitcher: pitcher,
      fielding_team: opponent,
      at_bat_index: 1,
      plate_appearance_number: 1,
      inning: 1,
      half_inning: "top",
      event: "Strikeout",
      event_type: "strikeout",
      description: "Batter struck out.",
      complete: true,
      source_name: "MLB Stats API",
      last_synced_at: Time.current
    )
    200.times do |index|
      recent = index >= 100
      PitchDatum.create!(
        game: historical_game,
        plate_appearance: appearance,
        game_date: historical_game.official_date,
        game_pk: historical_game.mlb_id,
        at_bat_number: 1,
        pitch_number: index + 1,
        pitcher: pitcher.mlb_id,
        batter: 888_001,
        stand: index.even? ? "L" : "R",
        p_throws: "R",
        pitch_type: recent ? "FF" : "SL",
        pitch_name: recent ? "4-Seam Fastball" : "Slider",
        release_speed: recent ? 96.0 : 86.0,
        pfx_x: recent ? -0.6 : 0.3,
        pfx_z: recent ? 1.2 : 0.2,
        balls: index % 4,
        strikes: [ index % 3, 2 ].min,
        zone: (index % 9) + 1,
        n_thruorder_pitcher: 1,
        description: index % 5 == 0 ? "swinging_strike" : "called_strike",
        events: index == 199 ? "strikeout" : nil
      )
    end
    TeamDailyMetric.create!(
      team: opponent,
      metric_date: Date.current - 1.day,
      source_start_date: Date.current - 1.day,
      source_end_date: Date.current - 1.day,
      sample_size: 1,
      calculation_version: DailyAnalyticsRefresh::CALCULATION_VERSION,
      calculated_at: Time.current,
      source_name: DailyAnalyticsRefresh::SOURCE_NAME,
      metrics: {
        games: 1, wins: 1, losses: 0, runs_scored: 4, at_bats: 30, hits: 9,
        doubles: 2, triples: 0, home_runs: 1, walks: 3, hit_by_pitch: 0,
        sacrifice_flies: 1, pitching_outs_recorded: 27, pitching_earned_runs: 2
      }
    )

    result = described_class.new(
      team: team,
      upcoming_games: [ upcoming_game ],
      season: Date.current.year,
      on: Date.current
    ).result
    report = result.fetch(:probable_starters).first

    expect(result.fetch(:opponent)).to include(id: opponent.id, abbreviation: "CLE")
    expect(result.fetch(:recent_performance)).to include(games: 1, wins: 1, losses: 0, runs_per_game: 4.0, era: 2.0)
    expect(report).to include(throws: "R", sample_size: 200)
    expect(report.fetch(:repertoire)).to include(
      hash_including(pitch_type: "FF", usage_percentage: 50.0, average_velocity: 96.0, horizontal_break: -7.2, vertical_break: 14.4)
    )
    expect(report.fetch(:handedness_splits).map { |split| split.fetch(:batter_hand) }).to eq(%w[L R])
    expect(report.fetch(:usage_by_count)).not_to be_empty
    expect(report.dig(:first_pitch_tendencies, :pitches)).to eq(1)
    expect(report.dig(:two_strike_tendencies, :pitches)).to be > 0
    expect(report.fetch(:location_zones)).to include(hash_including(label: "Zone 1"))
    expect(report.fetch(:put_away_pitches)).to include(hash_including(pitch_type: "FF", strikeouts: 1))
    expect(report.fetch(:times_through_order)).to include(hash_including(order: 1, plate_appearances: 1))
    expect(report.fetch(:hitter_attack_plan).length).to be >= 2
    expect(report.fetch(:recent_changes)).to include(hash_including(key: "velocity", change: 10.0, unit: "mph"))
    expect(report.dig(:repertoire, 0, :evidence, 0)).to include(
      game_id: historical_game.id,
      plate_appearance_id: appearance.id,
      pitch_id: kind_of(Integer)
    )
  end
end
