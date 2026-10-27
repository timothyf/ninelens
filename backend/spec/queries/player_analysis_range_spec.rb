require "rails_helper"

RSpec.describe PlayerAnalysisRange do
  let(:player) { create_player }

  before do
    PitchDatum.create!(
      game_pk: 900_001, game_date: Date.new(2026, 7, 15), at_bat_number: 1,
      pitch_number: 1, batter: player.mlb_id
    )
  end

  it "resolves full-season and trailing-day presets from the latest stored data" do
    season = described_class.resolve(player: player, params: { range: "season" })
    last_seven = described_class.resolve(player: player, params: { range: "7" })

    expect(season.to_h).to include(
      preset: "season",
      start_date: Date.new(2026, 1, 1),
      end_date: Date.new(2026, 7, 15),
      plate_appearance_window: 50,
      pitch_window: 100
    )
    expect(last_seven.to_h).to include(
      start_date: Date.new(2026, 7, 9),
      end_date: Date.new(2026, 7, 15),
      previous_start_date: Date.new(2026, 7, 2),
      previous_end_date: Date.new(2026, 7, 8)
    )
  end

  it "validates custom ranges and rolling-window options" do
    range = described_class.resolve(
      player: player,
      params: { range: "custom", start_date: "2026-06-01", end_date: "2026-06-30", pa_window: "100", pitch_window: "250" }
    )

    expect(range.to_h).to include(
      start_date: Date.new(2026, 6, 1),
      end_date: Date.new(2026, 6, 30),
      previous_start_date: Date.new(2026, 5, 2),
      previous_end_date: Date.new(2026, 5, 31),
      plate_appearance_window: 100,
      pitch_window: 250
    )

    expect do
      described_class.resolve(player: player, params: { range: "custom", start_date: "2026-06-30", end_date: "2026-06-01" })
    end.to raise_error(ArgumentError, "End date must be on or after start date")
    expect do
      described_class.resolve(player: player, params: { range: "7", pa_window: "75" })
    end.to raise_error(ArgumentError, "Pa window must be one of: 25, 50, 100")
  end
end
