require "rails_helper"

RSpec.describe PlayerTrendQuery do
  let(:player) { create_player }
  let(:start_date) { Date.new(2026, 7, 1) }
  let(:end_date) { Date.new(2026, 7, 3) }
  let(:analysis_range) do
    PlayerAnalysisRange.resolve(
      player: player,
      params: { range: "custom", start_date: start_date.iso8601, end_date: end_date.iso8601, pa_window: 25, pitch_window: 50 }
    )
  end

  before do
    create_pitch(1, 1, batter: player.mlb_id, description: "hit_into_play", zone: 5, launch_speed: 90)
    create_pitch(2, 1, batter: player.mlb_id, description: "hit_into_play", zone: 5, launch_speed: 100)
    create_pitch(3, 1, batter: player.mlb_id, description: "swinging_strike", zone: 11)

    create_pitch(1, 2, pitcher: player.mlb_id, description: "called_strike", zone: 5, pitch_type: "FF", release_speed: 94)
    create_pitch(2, 2, pitcher: player.mlb_id, description: "swinging_strike", zone: 11, pitch_type: "FF", release_speed: 96)
    create_pitch(3, 2, pitcher: player.mlb_id, description: "hit_into_play", zone: 5, pitch_type: "SL", release_speed: 86)
  end

  it "returns period comparisons and exact PA/pitch rolling trend series" do
    result = described_class.new(player: player, analysis_range: analysis_range).result

    expect(result.dig(:range, :plate_appearance_window)).to eq(25)
    expect(result.dig(:summary, :current, :batting)).to include(
      plate_appearances: 3,
      average_exit_velocity: 95.0,
      hard_hit_percentage: 50.0,
      whiff_percentage: 33.3333,
      chase_percentage: 100.0
    )
    expect(result.dig(:summary, :current, :pitching)).to include(
      pitch_count: 3,
      average_velocity: 92.0,
      whiff_percentage: 50.0,
      chase_percentage: 100.0
    )

    exit_chart = result.dig(:batting, :charts).find { |chart| chart[:key] == "exit_velocity" }
    expect(exit_chart.dig(:series, 0, :points).last).to include(value: 95.0, sample_size: 2)
    usage_chart = result.dig(:pitching, :charts).find { |chart| chart[:key] == "pitch_usage" }
    expect(usage_chart[:series].map { |series| series[:key] }).to eq(%w[FF SL])
    expect(usage_chart[:series].first[:points].last[:value]).to be_within(0.001).of(66.6667)
  end

  def create_pitch(day, pitch_number, attributes)
    PitchDatum.create!(
      {
        game_pk: 910_000 + day,
        game_date: Date.new(2026, 7, day),
        at_bat_number: day,
        pitch_number: pitch_number
      }.merge(attributes)
    )
  end
end
