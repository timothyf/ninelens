require "rails_helper"

RSpec.describe PitchDataImporter, type: :service do
  it "replaces a single game's local pitches when requested" do
    game = create_game
    PitchDatum.create!(game: game, game_pk: game.mlb_id, at_bat_number: 1, pitch_number: 1)

    result = described_class.import_raw_rows(
      rows: [ { "game_pk" => game.mlb_id.to_s, "at_bat_number" => "2", "pitch_number" => "1", "game_date" => game.official_date.iso8601 } ],
      source_name: "spec replacement",
      replace_game_id: game.id
    )

    expect(result).to include(success: true)
    expect(PitchDatum.where(game_id: game.id).pluck(:at_bat_number, :pitch_number)).to eq([ [ 2, 1 ] ])
  end

  it "imports pitch data rows and upserts duplicate pitch identities" do
    game = create_game(mlb_id: 1001)
    plate_appearance = PlateAppearance.create!(
      game: game,
      at_bat_index: 2,
      plate_appearance_number: 3,
      source_name: "MLB Stats API",
      last_synced_at: Time.current,
      raw_data: { "about" => { "atBatIndex" => 2 } }
    )
    csv_data = <<~CSV
      source_start_date,source_end_date,fetched_at_utc,game_date,game_pk,game_type,home_team,away_team,inning,inning_topbot,at_bat_number,pitch_number,pitcher,player_name,batter,stand,p_throws,pitch_type,pitch_name,description,events,balls,strikes,release_speed,release_spin_rate,bat_score,fielder_2,on_1b,if_fielding_alignment,vx0,woba_denom
      2026-04-01,2026-04-30,2026-05-01T00:00:00Z,2026-04-15,1001,R,DET,LAD,1,Top,3,1,9001,Pitcher One,8001,R,R,FF,4-Seam Fastball,called_strike,strikeout,0,1,96.3,2450.7,0,7001,4001,Standard,-7.2,1
      2026-04-01,2026-04-30,2026-05-01T00:00:00Z,2026-04-15,1001,R,DET,LAD,1,Top,3,1,9001,Pitcher One,8001,R,R,FF,4-Seam Fastball,foul,strikeout,0,2,96.7,2460.1,0,7001,4001,Standard,-7.0,1
      2026-04-01,2026-04-30,2026-05-01T00:00:00Z,2026-04-15,1001,R,DET,LAD,1,Top,3,2,9001,Pitcher One,8001,R,R,SL,Slider,ball,walk,1,2,85.2,2710.3,0,7001,4001,Standard,-6.5,1
    CSV

    result = described_class.call(csv_data: csv_data, source_name: "spec/imports/pitch_data.csv")

    expect(result[:success]).to be(true)
    expect(result.dig(:data, :imported_count)).to eq(2)
    expect(result.dig(:data, :skipped_count)).to eq(0)
    expect(result.dig(:data, :duplicate_count)).to eq(1)

    expect(PitchDatum.count).to eq(2)

    first_pitch = PitchDatum.find_by!(game_pk: 1001, at_bat_number: 3, pitch_number: 1)
    second_pitch = PitchDatum.find_by!(game_pk: 1001, at_bat_number: 3, pitch_number: 2)

    expect(first_pitch.description).to eq("foul")
    expect(first_pitch.release_speed).to eq(96.7)
    expect(first_pitch.release_spin_rate).to eq(2460.1)
    expect(first_pitch.bat_score).to eq(0)
    expect(first_pitch.fielder_2).to eq(7001)
    expect(first_pitch.on_1b).to eq(4001)
    expect(first_pitch.if_fielding_alignment).to eq("Standard")
    expect(first_pitch.vx0).to eq(-7.0)
    expect(first_pitch.woba_denom).to eq(1)
    expect(second_pitch.pitch_type).to eq("SL")
    expect(first_pitch.game).to eq(game)
    expect(second_pitch.game).to eq(game)
    expect(first_pitch.plate_appearance).to eq(plate_appearance)
    expect(second_pitch.plate_appearance).to eq(plate_appearance)
    expect(result.dig(:data, :linked_game_count)).to eq(2)
    expect(result.dig(:data, :unlinked_game_count)).to eq(0)
    expect(result.dig(:data, :analytics_refresh, :success)).to be(true)
  end

  it "leaves pitches nullable when their canonical game has not been synchronized" do
    csv_data = <<~CSV
      game_pk,at_bat_number,pitch_number,game_date,pitch_type
      999999,1,1,2026-04-15,FF
    CSV

    result = described_class.call(csv_data: csv_data, source_name: "spec/imports/unmatched_pitch_data.csv")

    expect(result[:success]).to be(true)
    expect(PitchDatum.last.game).to be_nil
    expect(result.dig(:data, :linked_game_count)).to eq(0)
    expect(result.dig(:data, :unlinked_game_count)).to eq(1)
  end

  it "stores active spin from either source field without retaining the source row" do
    csv_data = <<~CSV
      game_pk,at_bat_number,pitch_number,game_date,active_spin,spin_efficiency
      990001,1,1,2026-04-15,91.5,87.0
      990001,1,2,2026-04-15,,82.25
    CSV

    result = described_class.call(csv_data: csv_data, source_name: "spec/active_spin.csv")

    expect(result[:success]).to be(true)
    expect(PitchDatum.where(game_pk: 990001).order(:pitch_number).pluck(:active_spin)).to eq([91.5, 82.25])
    expect(PitchDatum.column_names).not_to include("raw_data")
  end

  it "returns failure when required columns are missing" do
    csv_data = <<~CSV
      game_date,game_type,pitch_number
      2026-04-15,R,1
    CSV

    result = described_class.call(csv_data: csv_data, source_name: "spec/imports/bad_pitch_data.csv")

    expect(result[:success]).to be(false)
    expect(result[:message]).to include("Missing required columns")
  end
end
