require "rails_helper"

RSpec.describe PlayerTrendEventDetector, type: :service do
  let(:player) { create_player(attributes: { mlb_id: 456_789 }) }
  let(:as_of) { Date.new(2026, 7, 20) }

  before do
    create_pitcher_windows
    create_batter_windows
  end

  it "detects velocity loss, pitch-mix changes, and chase-rate movement with evidence" do
    result = described_class.new(player: player, as_of: as_of).result

    velocity = result.candidates.find do |candidate|
      candidate[:event_type] == "velocity_loss" && candidate[:pitch_type] == "FF"
    end
    expect(velocity).to include(
      role: "pitcher",
      severity: "critical",
      direction: "decrease",
      baseline_value: 96.0,
      current_value: 93.5,
      change_value: -2.5,
      threshold_value: 2.0,
      baseline_sample_size: 60,
      sample_size: 40,
      onset_date: Date.new(2026, 7, 2)
    )
    expect(velocity[:thresholds]).to eq("warning" => 1.0, "critical" => 2.0)
    expect(velocity[:supporting_pitches]).not_to be_empty
    expect(velocity[:supporting_pitches].first).to include(
      "pitch_data_id",
      "game_pk",
      "game_date" => "2026-07-02",
      "release_speed" => 93.5
    )

    mix = result.candidates.find do |candidate|
      candidate[:event_type] == "pitch_mix_change" && candidate[:pitch_type] == "FF"
    end
    expect(mix).to include(
      severity: "critical",
      direction: "decrease",
      baseline_value: 60.0,
      current_value: 40.0,
      change_value: -20.0,
      sample_size: 100
    )

    pitcher_chase = result.candidates.find do |candidate|
      candidate[:event_type] == "chase_rate_movement" && candidate[:role] == "pitcher"
    end
    expect(pitcher_chase).to include(
      severity: "critical",
      direction: "increase",
      baseline_value: 20.0,
      current_value: 50.0,
      change_value: 30.0,
      baseline_sample_size: 30,
      sample_size: 30
    )

    batter_chase = result.candidates.find do |candidate|
      candidate[:event_type] == "chase_rate_movement" && candidate[:role] == "batter"
    end
    expect(batter_chase).to include(
      severity: "critical",
      direction: "increase",
      baseline_value: 20.0,
      current_value: 40.0,
      change_value: 20.0,
      baseline_sample_size: 50,
      sample_size: 50
    )
  end

  it "persists candidates idempotently and updates their observation time" do
    first_time = Time.zone.parse("2026-07-20 12:00:00")
    second_time = first_time + 1.hour

    first = PlayerTrendEventRefresh.call(players: [ player ], as_of: as_of, observed_at: first_time)
    event_count = player.trend_events.count
    second = PlayerTrendEventRefresh.call(players: [ player ], as_of: as_of, observed_at: second_time)

    expect(first).to include(success: true)
    expect(first.dig(:data, :created)).to eq(event_count)
    expect(second.dig(:data, :created)).to eq(0)
    expect(second.dig(:data, :updated)).to eq(event_count)
    expect(player.trend_events.count).to eq(event_count)
    expect(player.trend_events.pluck(:last_observed_at).uniq).to eq([ second_time ])
  end

  it "resolves an active event once an evaluated metric no longer crosses its threshold" do
    identity = "velocity_loss:pitcher:average_velocity:FF"
    event = create_event(identity_key: identity)
    detector_result = described_class::Result.new([], [ identity ])
    detector = instance_double(described_class, result: detector_result)
    allow(described_class).to receive(:new).and_return(detector)

    result = PlayerTrendEventRefresh.call(players: [ player ], as_of: as_of)

    expect(result.dig(:data, :resolved)).to eq(1)
    expect(event.reload).to have_attributes(status: "resolved")
    expect(event.resolved_at).to be_present
  end

  private

  def create_pitcher_windows
    200.times do |index|
      current = index >= 100
      within_window = index % 100
      fastball = current ? within_window < 40 : within_window < 60
      chase = within_window < 30
      chase_swing_count = current ? 15 : 6

      PitchDatum.create!(
        game_pk: current ? 920_002 : 920_001,
        game_date: current ? Date.new(2026, 7, 2) : Date.new(2026, 7, 1),
        at_bat_number: (index / 4) + 1,
        pitch_number: (index % 4) + 1,
        pitcher: player.mlb_id,
        pitch_type: fastball ? "FF" : "SL",
        pitch_name: fastball ? "4-Seam Fastball" : "Slider",
        release_speed: fastball ? (current ? 93.5 : 96.0) : 86.0,
        zone: chase ? 11 : 5,
        description: chase && within_window < chase_swing_count ? "swinging_strike" : "called_strike"
      )
    end
  end

  def create_batter_windows
    100.times do |index|
      current = index >= 50
      within_window = index % 50
      swing_count = current ? 20 : 10
      PitchDatum.create!(
        game_pk: 930_000 + index,
        game_date: current ? Date.new(2026, 7, 20) : Date.new(2026, 7, 10),
        at_bat_number: 1,
        pitch_number: 1,
        batter: player.mlb_id,
        pitch_type: "FF",
        zone: 11,
        description: within_window < swing_count ? "foul" : "called_strike"
      )
    end
  end

  def create_event(identity_key:)
    player.trend_events.create!(
      identity_key: identity_key,
      event_type: "velocity_loss",
      role: "pitcher",
      metric_key: "average_velocity",
      pitch_type: "FF",
      direction: "decrease",
      severity: "warning",
      status: "active",
      unit: "mph",
      baseline_value: 96.0,
      current_value: 94.5,
      change_value: -1.5,
      threshold_value: 1.0,
      baseline_sample_size: 20,
      sample_size: 20,
      baseline_start_date: Date.new(2026, 7, 1),
      baseline_end_date: Date.new(2026, 7, 1),
      current_start_date: Date.new(2026, 7, 2),
      current_end_date: Date.new(2026, 7, 2),
      onset_date: Date.new(2026, 7, 2),
      detected_at: Time.current,
      last_observed_at: Time.current,
      calculation_version: described_class::CALCULATION_VERSION,
      thresholds: { "warning" => 1.0, "critical" => 2.0 },
      supporting_pitches: [],
      metadata: {}
    )
  end
end
