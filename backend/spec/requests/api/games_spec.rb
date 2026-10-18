require "rails_helper"

RSpec.describe "Api::Games", type: :request do
  before do
    @tigers = create_team(
      mlb_id: 116,
      name: "Detroit Tigers",
      abbreviation: "DET",
      team_name: "Tigers",
      location_name: "Detroit",
      short_name: "Detroit"
    )
    @guardians = create_team(
      mlb_id: 114,
      name: "Cleveland Guardians",
      abbreviation: "CLE",
      team_name: "Guardians",
      location_name: "Cleveland",
      short_name: "Cleveland"
    )
    @schedule = create_schedule(
      season: 2026,
      schedule_type: "R",
      start_date: Date.new(2026, 3, 25),
      end_date: Date.new(2026, 9, 27),
      source_key: "mlb:schedule:1:2026:R",
      last_synced_at: Time.zone.parse("2026-07-14T12:00:00Z")
    )
    @skubal = create_player(
      team: @tigers,
      attributes: { mlb_id: 669_373, first_name: "Tarik", last_name: "Skubal" }
    )
    @bibee = create_player(
      team: @guardians,
      attributes: { mlb_id: 676_440, first_name: "Tanner", last_name: "Bibee" }
    )
    @game = create_game(
      schedule: @schedule,
      mlb_id: 823_443,
      official_date: Date.new(2026, 7, 14),
      scheduled_at: Time.zone.parse("2026-07-14T18:10:00Z"),
      game_type: "R",
      status: "preview",
      detailed_status: "Pre-Game",
      home_team: @tigers,
      away_team: @guardians,
      home_probable_pitcher: @skubal,
      away_probable_pitcher: @bibee,
      venue_name: "Comerica Park",
      source_name: "MLB Stats API",
      source_url: "https://statsapi.mlb.com/api/v1.1/game/823443/feed/live",
      last_synced_at: Time.zone.parse("2026-07-14T12:00:00Z")
    )
  end

  it "returns filtered, paginated games" do
    create_game(
      schedule: @schedule,
      official_date: Date.new(2026, 7, 20),
      status: "final",
      game_type: "R"
    )

    get api_games_path,
        params: {
          team_id: @tigers.id,
          start_date: "2026-07-14",
          end_date: "2026-07-14",
          season: 2026,
          status: "preview",
          game_type: "R"
        }

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("meta", "total_count")).to eq(1)
    expect(json_body.dig("meta", "filters", "team_id")).to eq(@tigers.id)
    expect(json_body.dig("meta", "filters", "start_date")).to eq("2026-07-14")
    expect(json_body.fetch("data").map { |game| game.fetch("mlb_id") }).to eq([ 823_443 ])
  end

  it "returns game details with teams, probable pitchers, source metadata, and schedule" do
    get api_game_path(@game)

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", "home_team", "abbreviation")).to eq("DET")
    expect(json_body.dig("data", "away_team", "abbreviation")).to eq("CLE")
    expect(json_body.dig("data", "home_probable_pitcher", "full_name")).to eq("Tarik Skubal")
    expect(json_body.dig("data", "away_probable_pitcher", "full_name")).to eq("Tanner Bibee")
    expect(json_body.dig("data", "source_name")).to eq("MLB Stats API")
    expect(json_body.dig("data", "source_url")).to include("823443")
    expect(json_body.dig("data", "last_synced_at")).to eq("2026-07-14T12:00:00.000Z")
    expect(json_body.dig("data", "schedule", "source_key")).to eq("mlb:schedule:1:2026:R")

    @game.update!(live_feed_raw_data: {
      "liveData" => {
        "linescore" => {
          "currentInning" => 5,
          "currentInningOrdinal" => "5th",
          "inningState" => "Top"
        }
      }
    })

    get api_game_path(@game)

    expect(json_body.dig("data", "current_inning")).to eq(5)
    expect(json_body.dig("data", "current_inning_ordinal")).to eq("5th")
    expect(json_body.dig("data", "inning_state")).to eq("Top")
  end

  it "returns normalized box-score and plate-appearance drill-down data" do
    @game.update!(
      details_source_url: "https://statsapi.mlb.com/api/v1.1/game/823443/feed/live",
      details_last_synced_at: Time.zone.parse("2026-07-14T23:00:00Z"),
      home_score: 3,
      away_score: 1,
      live_feed_raw_data: {
        "liveData" => {
          "linescore" => {
            "currentInning" => 9,
            "currentInningOrdinal" => "9th",
            "inningState" => "End",
            "innings" => [
              { "num" => 1, "ordinalNum" => "1st", "away" => { "runs" => 1 }, "home" => { "runs" => 0 } },
              { "num" => 2, "ordinalNum" => "2nd", "away" => { "runs" => 0 }, "home" => { "runs" => 3 } }
            ],
            "teams" => {
              "away" => { "runs" => 1, "hits" => 5, "errors" => 0, "leftOnBase" => 6 },
              "home" => { "runs" => 3, "hits" => 8, "errors" => 1, "leftOnBase" => 7 }
            }
          }
        }
      }
    )
    GamePlayerBattingLine.create!(
      game: @game,
      player: @skubal,
      team: @tigers,
      opponent_team: @guardians,
      home: true,
      starter: true,
      batting_order: 900,
      at_bats: 4,
      runs: 1,
      hits: 2,
      doubles: 1,
      home_runs: 1,
      runs_batted_in: 3,
      source_name: "MLB Stats API",
      last_synced_at: Time.current,
      raw_data: { "seasonStats" => { "batting" => { "avg" => ".287", "ops" => ".842" } } }
    )
    GamePlayerBattingLine.create!(
      game: @game,
      player: @bibee,
      team: @guardians,
      opponent_team: @tigers,
      home: false,
      starter: true,
      batting_order: 900,
      at_bats: 4,
      runs: 1,
      hits: 2,
      doubles: 1,
      runs_batted_in: 1,
      strikeouts: 1,
      source_name: "MLB Stats API",
      last_synced_at: Time.current
    )
    GamePlayerPitchingLine.create!(
      game: @game,
      player: @skubal,
      team: @tigers,
      opponent_team: @guardians,
      home: true,
      starter: true,
      appearance_order: 1,
      innings_pitched: "7.0",
      outs_recorded: 21,
      batters_faced: 25,
      hits: 4,
      runs: 1,
      earned_runs: 1,
      walks: 1,
      strikeouts: 9,
      home_runs: 0,
      source_name: "MLB Stats API",
      last_synced_at: Time.current,
      raw_data: { "seasonStats" => { "pitching" => { "era" => "2.01", "whip" => "0.99" } } }
    )
    GamePlayerPitchingLine.create!(
      game: @game,
      player: @bibee,
      team: @guardians,
      opponent_team: @tigers,
      home: false,
      starter: true,
      appearance_order: 1,
      innings_pitched: "6.0",
      outs_recorded: 18,
      batters_faced: 24,
      hits: 5,
      runs: 3,
      earned_runs: 3,
      walks: 2,
      strikeouts: 7,
      home_runs: 1,
      decision: "(L, 7-5)",
      source_name: "MLB Stats API",
      last_synced_at: Time.current
    )
    @game.game_player_pitching_lines.find_by!(player: @skubal).update!(decision: "(W, 11-2)")
    reliever = create_player(
      team: @tigers,
      attributes: { mlb_id: 700_111, first_name: "Will", last_name: "Vest" }
    )
    GamePlayerPitchingLine.create!(
      game: @game,
      player: reliever,
      team: @tigers,
      opponent_team: @guardians,
      home: true,
      starter: false,
      appearance_order: 2,
      innings_pitched: "1.0",
      outs_recorded: 3,
      batters_faced: 3,
      hits: 0,
      runs: 0,
      earned_runs: 0,
      walks: 0,
      strikeouts: 2,
      decision: "(S, 1)",
      source_name: "MLB Stats API",
      last_synced_at: Time.current
    )
    away_scoring_appearance = PlateAppearance.create!(
      game: @game,
      batter: @bibee,
      pitcher: @skubal,
      batting_team: @guardians,
      fielding_team: @tigers,
      at_bat_index: 0,
      plate_appearance_number: 1,
      inning: 1,
      half_inning: "top",
      event: "Single",
      event_type: "single",
      description: "Tanner Bibee singles, scoring Steven Kwan.",
      runs_batted_in: 1,
      away_score: 1,
      home_score: 0,
      complete: true,
      source_name: "MLB Stats API",
      last_synced_at: Time.current
    )
    home_first_scoring_appearance = PlateAppearance.create!(
      game: @game,
      batter: reliever,
      pitcher: @bibee,
      batting_team: @tigers,
      fielding_team: @guardians,
      at_bat_index: 1,
      plate_appearance_number: 2,
      inning: 2,
      half_inning: "bottom",
      event: "Double",
      event_type: "double",
      description: "Will Vest doubles, scoring a run.",
      runs_batted_in: 1,
      away_score: 1,
      home_score: 1,
      complete: true,
      source_name: "MLB Stats API",
      last_synced_at: Time.current
    )
    appearance = PlateAppearance.create!(
      game: @game,
      batter: @skubal,
      pitcher: @bibee,
      batting_team: @tigers,
      fielding_team: @guardians,
      at_bat_index: 2,
      plate_appearance_number: 3,
      inning: 4,
      half_inning: "bottom",
      event: "Home Run",
      event_type: "home_run",
      description: "Tarik Skubal homers, scoring two runs.",
      runs_batted_in: 2,
      away_score: 1,
      home_score: 3,
      complete: true,
      source_name: "MLB Stats API",
      last_synced_at: Time.current,
      raw_data: { "matchup" => { "splits" => { "menOnBase" => "RISP" } } }
    )
    PitchDatum.create!(
      game: @game,
      plate_appearance: appearance,
      game_pk: @game.mlb_id,
      at_bat_number: appearance.plate_appearance_number,
      pitch_number: 1,
      pitcher: @bibee.mlb_id,
      batter: @skubal.mlb_id,
      pitch_type: "FF",
      pitch_name: "4-Seam Fastball",
      description: "called_strike",
      balls: 0,
      strikes: 0,
      release_speed: 96.4,
      zone: 5,
      n_thruorder_pitcher: 2,
      raw_data: { "pitch_type" => "FF" }
    )
    [
      { pitch_number: 2, pitch_type: "FF", pitch_name: "4-Seam Fastball", description: "swinging_strike", release_speed: 97.0, zone: 11 },
      {
        pitch_number: 3, pitch_type: "SL", pitch_name: "Slider", description: "hit_into_play",
        balls: 0, strikes: 2, release_speed: 86.0, launch_speed: 99.0, launch_angle: 14.0,
        hit_distance_sc: 242.0, bb_type: "line_drive", estimated_woba_using_speedangle: 0.611, zone: 12
      },
      { pitch_number: 4, pitch_type: "SL", pitch_name: "Slider", description: "ball", release_speed: 85.0, zone: 12 }
    ].each do |attributes|
      PitchDatum.create!(
        game: @game,
        plate_appearance: appearance,
        game_pk: @game.mlb_id,
        at_bat_number: appearance.plate_appearance_number,
        pitcher: @bibee.mlb_id,
        batter: @skubal.mlb_id,
        n_thruorder_pitcher: 2,
        raw_data: attributes,
        **attributes
      )
    end
    PitchDatum.create!(
      game: @game,
      plate_appearance: home_first_scoring_appearance,
      game_pk: @game.mlb_id,
      at_bat_number: home_first_scoring_appearance.plate_appearance_number,
      pitch_number: 1,
      pitcher: @bibee.mlb_id,
      batter: reliever.mlb_id,
      pitch_type: "CH",
      pitch_name: "Changeup",
      description: "called_strike",
      release_speed: 88.0,
      zone: 4,
      n_thruorder_pitcher: 1,
      raw_data: { "pitch_type" => "CH" }
    )
    [
      { pitch_number: 1, description: "called_strike", pitch_type: "FF", pitch_name: "4-Seam Fastball", release_speed: 95.0, zone: 5 },
      { pitch_number: 2, description: "ball", pitch_type: "CH", pitch_name: "Changeup", release_speed: 86.0, zone: 13 }
    ].each do |attributes|
      PitchDatum.create!(
        game: @game,
        plate_appearance: away_scoring_appearance,
        game_pk: @game.mlb_id,
        at_bat_number: away_scoring_appearance.plate_appearance_number,
        pitcher: @skubal.mlb_id,
        batter: @bibee.mlb_id,
        n_thruorder_pitcher: 1,
        raw_data: attributes,
        **attributes
      )
    end

    get api_game_path(@game)

    expect(json_body.dig("data", "details")).to include(
      "synchronized" => true,
      "last_synced_at" => "2026-07-14T23:00:00.000Z"
    )
    expect(json_body.dig("data", "details", "line_score", "innings")).to eq(
      [
        {
          "number" => 1,
          "ordinal" => "1st",
          "away" => { "runs" => 1, "hits" => nil, "errors" => nil, "left_on_base" => nil },
          "home" => { "runs" => 0, "hits" => nil, "errors" => nil, "left_on_base" => nil }
        },
        {
          "number" => 2,
          "ordinal" => "2nd",
          "away" => { "runs" => 0, "hits" => nil, "errors" => nil, "left_on_base" => nil },
          "home" => { "runs" => 3, "hits" => nil, "errors" => nil, "left_on_base" => nil }
        }
      ]
    )
    expect(json_body.dig("data", "details", "line_score", "totals", "home")).to eq(
      "runs" => 3,
      "hits" => 8,
      "errors" => 1,
      "left_on_base" => 7
    )
    skubal_batting = json_body.dig("data", "details", "batting_lines").find do |line|
      line.dig("player", "full_name") == "Tarik Skubal"
    end
    expect(skubal_batting).to include(
      "batting_average" => "0.287",
      "ops" => "0.842"
    )
    expect(json_body.dig("data", "details", "pitching_lines", 0)).to include(
      "decision" => "(L, 7-5)"
    )
    expect(json_body.dig("data", "details", "pitching_lines", 1)).to include(
      "era" => "2.01",
      "whip" => "0.99",
      "decision" => "(W, 11-2)"
    )
    expect(json_body.dig("data", "details", "insights", "decisions", "winning_pitcher")).to include(
      "player" => include("full_name" => "Tarik Skubal"),
      "decision" => "(W, 11-2)"
    )
    expect(json_body.dig("data", "details", "insights", "decisions", "losing_pitcher")).to include(
      "player" => include("full_name" => "Tanner Bibee"),
      "decision" => "(L, 7-5)"
    )
    expect(json_body.dig("data", "details", "insights", "decisions", "save")).to include(
      "player" => include("full_name" => "Will Vest"),
      "decision" => "(S, 1)"
    )
    expect(json_body.dig("data", "details", "insights", "teams", "home")).to include(
      "run_differential" => 2,
      "hits" => 8,
      "errors" => 1,
      "runners_in_scoring_position" => { "hits" => 1, "at_bats" => 1 }
    )
    expect(json_body.dig("data", "details", "key_performers", "top_hitters", "away")).to include(
      "player" => include("full_name" => "Tanner Bibee"),
      "summary" => "2-for-4, 1 RBI, 1 R"
    )
    expect(json_body.dig("data", "details", "key_performers", "top_hitters", "home")).to include(
      "player" => include("full_name" => "Tarik Skubal"),
      "summary" => "2-for-4, 1 HR, 3 RBI, 1 R"
    )
    expect(json_body.dig("data", "details", "key_performers", "most_impactful_pitcher")).to include(
      "player" => include("full_name" => "Tarik Skubal"),
      "summary" => "7.0 IP, 1 ER, 9 K, W"
    )
    expect(json_body.dig("data", "details", "key_performers", "power_hitters")).to contain_exactly(
      include("player" => include("full_name" => "Tarik Skubal"), "summary" => "1 HR · 2 XBH")
    )
    expect(json_body.dig("data", "details", "key_performers", "scoreless_relievers")).to contain_exactly(
      include("player" => include("full_name" => "Will Vest"), "summary" => "1.0 scoreless IP · 2 K")
    )
    expect(json_body.dig("data", "details", "key_performers", "top_run_producers")).to contain_exactly(
      include("player" => include("full_name" => "Tarik Skubal"), "summary" => "3 runs produced · 1 R, 3 RBI")
    )
    expect(json_body.dig("data", "details", "scoring_plays")).to match(
      [
        hash_including(
          "inning_label" => "Top 1st",
          "description" => "Tanner Bibee singles, scoring Steven Kwan.",
          "runs_scored" => 1,
          "away_score" => 1,
          "home_score" => 0,
          "batter" => include("full_name" => "Tanner Bibee"),
          "batting_team" => include("abbreviation" => "CLE")
        ),
        hash_including(
          "inning_label" => "Bottom 2nd",
          "description" => "Will Vest doubles, scoring a run.",
          "runs_scored" => 1,
          "away_score" => 1,
          "home_score" => 1,
          "batter" => include("full_name" => "Will Vest"),
          "batting_team" => include("abbreviation" => "DET")
        ),
        hash_including(
          "inning_label" => "Bottom 4th",
          "description" => "Tarik Skubal homers, scoring two runs.",
          "runs_scored" => 2,
          "away_score" => 1,
          "home_score" => 3,
          "batter" => include("full_name" => "Tarik Skubal"),
          "batting_team" => include("abbreviation" => "DET")
        )
      ]
    )
    pitching_analysis = json_body.dig("data", "details", "pitching_analysis")
    bibee_analysis = pitching_analysis.find { |entry| entry.dig("player", "full_name") == "Tanner Bibee" }
    expect(bibee_analysis).to include(
      "pitch_count" => 5,
      "analyzed_pitch_count" => 5,
      "strike_count" => 4,
      "strike_percentage" => 80.0,
      "first_pitch_strikes" => 2,
      "first_pitch_opportunities" => 2,
      "first_pitch_strike_percentage" => 100.0,
      "swings" => 2,
      "whiffs" => 1,
      "whiff_percentage" => 50.0,
      "called_strikes" => 2,
      "csw_count" => 3,
      "csw_percentage" => 60.0,
      "average_velocity" => 90.5,
      "maximum_velocity" => 97.0,
      "chase_opportunities" => 3,
      "chases" => 2,
      "chase_percentage" => 66.7,
      "batters_faced" => 24
    )
    expect(bibee_analysis.fetch("pitch_usage")).to match(
      [
        hash_including(
          "pitch_type" => "FF", "count" => 2, "percentage" => 40.0, "average_velocity" => 96.7,
          "whiff_percentage" => 100.0, "csw_percentage" => 100.0, "average_exit_velocity" => nil
        ),
        hash_including(
          "pitch_type" => "SL", "count" => 2, "percentage" => 40.0, "average_velocity" => 85.5,
          "whiff_percentage" => 0.0, "csw_percentage" => 0.0, "average_exit_velocity" => 99.0
        ),
        hash_including(
          "pitch_type" => "CH", "count" => 1, "percentage" => 20.0, "average_velocity" => 88.0,
          "whiff_percentage" => nil, "csw_percentage" => 100.0, "average_exit_velocity" => nil
        )
      ]
    )
    expect(bibee_analysis.fetch("times_through_order")).to eq(
      "maximum" => 2,
      "plate_appearances" => [
        { "time" => 1, "batters_faced" => 1 },
        { "time" => 2, "batters_faced" => 1 }
      ]
    )
    expect(pitching_analysis.map { |entry| entry.dig("player", "full_name") }).to contain_exactly(
      "Tanner Bibee", "Tarik Skubal", "Will Vest"
    )
    batted_ball_analysis = json_body.dig("data", "details", "batted_ball_analysis")
    expect(batted_ball_analysis.map { |entry| entry.dig("team", "abbreviation") }).to eq([ "CLE", "DET" ])
    expect(batted_ball_analysis.first).to include("batted_balls" => 0, "leaders" => [])
    expect(batted_ball_analysis.second).to include("batted_balls" => 1)
    situational_analysis = json_body.dig("data", "details", "situational_analysis")
    expect(situational_analysis.fetch("teams").map { |entry| entry.dig("team", "abbreviation") }).to eq([ "CLE", "DET" ])
    expect(situational_analysis.dig("turning_point")).to include(
      "type" => "scoring_play", "inning_label" => "Bottom 4th", "runs_scored" => 2
    )
    expect(json_body.dig("data", "details", "plate_appearances", 0)).to include(
      "event_type" => "single",
      "plate_appearance_number" => 1
    )
    serialized_pitch = json_body.dig("data", "details", "plate_appearances")
      .flat_map { |plate_appearance| plate_appearance.fetch("pitches") }
      .find { |pitch| pitch["release_speed"] == 96.4 }
    expect(serialized_pitch).to include(
      "pitch_type" => "FF",
      "release_speed" => 96.4,
      "balls" => 0,
      "strikes" => 0
    )
    contact_pitch = json_body.dig("data", "details", "plate_appearances")
      .flat_map { |plate_appearance| plate_appearance.fetch("pitches") }
      .find { |pitch| pitch["launch_speed"] == 99.0 }
    expect(contact_pitch).to include(
      "launch_angle" => 14.0, "hit_distance_sc" => 242.0,
      "bb_type" => "line_drive", "estimated_woba_using_speedangle" => 0.611
    )
  end

  it "returns future preview and scheduled games from the upcoming endpoint" do
    upcoming_game = create_game(
      schedule: @schedule,
      home_team: @guardians,
      away_team: @tigers,
      official_date: Date.current + 2.days,
      scheduled_at: Time.current + 2.days,
      status: "scheduled"
    )
    create_game(
      schedule: @schedule,
      official_date: Date.current - 1.day,
      scheduled_at: Time.current - 1.day,
      status: "final"
    )

    get upcoming_api_games_path, params: { team_id: @tigers.id }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("data").map { |game| game.fetch("id") }).to include(upcoming_game.id)
    expect(json_body.fetch("data")).to all(include("status" => satisfy { |status| %w[preview scheduled].include?(status) }))
  end
end
