require "rails_helper"

RSpec.describe "Production user writes", type: :request do
  before do
    allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new("production"))
  end

  it "allows an analyst to create a note through its role-based authorization" do
    analyst = create_user(role: "analyst")
    player = create_player

    post api_notes_path,
      params: { target_type: "player", target_id: player.id, body: "Production authorization works." },
      headers: user_headers(analyst), as: :json

    expect(response).to have_http_status(:created)
    expect(Note.last.author).to eq(analyst)
  end

  it "allows a scout to create an owned watchlist" do
    scout = create_user(role: "scout")

    post api_watchlists_path,
      params: { name: "Production targets", description: "Authorized by ownership" },
      headers: user_headers(scout), as: :json

    expect(response).to have_http_status(:created)
    expect(Watchlist.last.owner).to eq(scout)
  end

  it "allows a signed-in viewer to save an analysis" do
    viewer = create_user(role: "viewer")

    post api_saved_analyses_path,
      params: {
        name: "Production leaderboard",
        analysis_type: "stat_explorer",
        visibility: "private",
        reproducible_url: "/explore?category=batting",
        state: { category: "batting" }
      },
      headers: user_headers(viewer), as: :json

    expect(response).to have_http_status(:created)
    expect(SavedAnalysis.last.owner).to eq(viewer)
  end

  it "allows a signed-in viewer to create a personal alert subscription" do
    viewer = create_user(role: "viewer")
    player = create_player

    post api_alert_subscriptions_path,
      params: { player_id: player.id, name: "Production alerts", minimum_severity: "warning" },
      headers: user_headers(viewer), as: :json

    expect(response).to have_http_status(:created)
    expect(AlertSubscription.last.user).to eq(viewer)
  end
end
