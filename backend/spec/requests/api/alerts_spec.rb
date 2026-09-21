require "rails_helper"

RSpec.describe "Api::Alerts", type: :request do
  let(:owner) { create_user }
  let(:auth_headers) { user_headers(owner) }
  let(:player) { create_player }

  def create_event
    player.trend_events.create!(
      identity_key: "chase_rate_movement:batter:chase_percentage:all",
      event_type: "chase_rate_movement", role: "batter", metric_key: "chase_percentage",
      direction: "increase", severity: "warning", status: "active", unit: "percentage_points",
      baseline_value: 25, current_value: 35, change_value: 10, threshold_value: 8,
      baseline_sample_size: 30, sample_size: 32,
      baseline_start_date: Date.new(2026, 6, 1), baseline_end_date: Date.new(2026, 6, 15),
      current_start_date: Date.new(2026, 6, 16), current_end_date: Date.new(2026, 6, 30),
      onset_date: Date.new(2026, 6, 16), detected_at: Time.current, last_observed_at: Time.current,
      calculation_version: "1.0.0", thresholds: { warning: 8, critical: 15 },
      supporting_pitches: [ { game_pk: 123, pitch_number: 4 } ], metadata: { window_size: 50 }
    )
  end

  it "creates a player subscription and exposes evidence and deep links in the inbox" do
    event = create_event
    post api_alert_subscriptions_path, params: { player_id: player.id, minimum_severity: "warning" }, headers: auth_headers

    expect(response).to have_http_status(:created)
    expect(Alert.count).to eq(1)

    get api_alerts_path, headers: auth_headers
    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", 0, "severity")).to eq("warning")
    expect(json_body.dig("data", 0, "evidence", "supporting_pitches")).to be_present
    expect(json_body.dig("data", 0, "links", "chart")).to include("event_id=#{event.id}")
  end

  it "supports acknowledge, snooze, assign, and digest preferences" do
    event = create_event
    subscription = owner.alert_subscriptions.create!(player: player)
    AlertInboxSync.call(user: owner)
    alert = Alert.find_by!(user: owner, player_trend_event: event)
    assignee = create_user

    post acknowledge_api_alert_path(alert), headers: auth_headers
    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", "status")).to eq("acknowledged")

    post snooze_api_alert_path(alert), params: { until: 2.days.from_now.iso8601 }, headers: auth_headers
    expect(json_body.dig("data", "status")).to eq("snoozed")
    post assign_api_alert_path(alert), params: { user_id: assignee.id }, headers: auth_headers
    expect(json_body.dig("data", "assigned_to", "id")).to eq(assignee.id)

    patch api_alert_digest_path, params: { alert_digest_frequency: "weekly", alert_digest_day: 1, alert_digest_hour: 9 }, headers: auth_headers
    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", "frequency")).to eq("weekly")
  end
end
