require "rails_helper"

RSpec.describe "Api::Watchlists", type: :request do
  let(:owner) { create_user }
  let(:auth_headers) { user_headers(owner) }

  it "creates watchlists and persists structured acquisition evaluations" do
    team = create_team(name: "Detroit Tigers", abbreviation: "DET")
    player = create_player(team: team, attributes: { first_name: "Target", last_name: "Player" })

    post api_watchlists_path, params: { name: "Trade targets", description: "Deadline candidates" }, headers: auth_headers

    expect(response).to have_http_status(:created)
    watchlist_id = json_body.dig("data", "id")

    post api_watchlist_watchlist_entries_path(watchlist_id), params: { player_id: player.id }, headers: auth_headers

    expect(response).to have_http_status(:created)
    entry_id = json_body.dig("data", "id")
    expect(json_body.dig("data", "recommendation")).to eq("monitor")

    patch api_watchlist_entry_path(entry_id), params: {
      priority: "high", status: "active", recommendation: "pursue",
      fit_score: 5, need_score: 4, cost_score: 3, risk_score: 2,
      tags: [ "Power", " power ", "trade target" ], notes: "Fits the middle of the order."
    }, headers: auth_headers

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", "tags")).to eq([ "power", "trade target" ])
    expect(json_body.dig("data", "fit_score")).to eq(5)
    expect(json_body.dig("data", "player", "full_name")).to eq("Target Player")

    get api_watchlists_path, headers: auth_headers

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", 0, "entries", 0, "recommendation")).to eq("pursue")
  end

  it "assigns candidates and supports the review-status workflow with acquisition details" do
    team = create_team
    player = create_player(team: team)
    candidate_owner = create_user(role: "scout")
    watchlist = Watchlist.create!(name: "Workflow targets", owner: owner)

    post api_watchlist_watchlist_entries_path(watchlist), params: {
      player_id: player.id,
      candidate_owner_id: candidate_owner.id,
      acquisition_rationale: "Adds left-handed impact and defensive flexibility.",
      estimated_cost: 12_500_000,
      availability: "potentially_available",
      concerns: "Would require a medical review."
    }, headers: auth_headers

    expect(response).to have_http_status(:created)
    entry_id = json_body.dig("data", "id")
    expect(json_body.dig("data", "candidate_owner", "id")).to eq(candidate_owner.id)
    expect(json_body.dig("data", "candidate_owner")).to include(
      "name" => candidate_owner.name,
      "email" => candidate_owner.email,
      "role" => candidate_owner.role
    )
    expect(json_body.dig("data", "review_status")).to eq("initial_review")
    expect(json_body.dig("data", "estimated_cost")).to eq(12_500_000.0)

    created_entry = json_body.fetch("data")
    get api_watchlist_path(watchlist), headers: auth_headers
    expect(json_body.dig("data", "entries", 0)).to eq(created_entry)

    post transition_api_watchlist_entry_path(entry_id), params: { review_status: "analyst_review" }, headers: auth_headers
    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", "review_status")).to eq("analyst_review")

    post transition_api_watchlist_entry_path(entry_id), params: { review_status: "contact_club_or_agent" }, headers: auth_headers
    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", "review_status")).to eq("contact_club_or_agent")

    post transition_api_watchlist_entry_path(entry_id), params: { review_status: "not_a_review_status" }, headers: auth_headers
    expect(response).to have_http_status(:unprocessable_content)

    get audit_history_api_watchlist_entry_path(entry_id), headers: auth_headers
    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("data").map { |event| event.fetch("action") }).to include("review_status_changed")
  end

  it "prevents duplicate targets and rejects out-of-range evaluation scores" do
    watchlist = Watchlist.create!(name: "Free agents", owner: owner)
    entry = watchlist.entries.create!(player: create_player)

    post api_watchlist_watchlist_entries_path(watchlist), params: { player_id: entry.player_id }, headers: auth_headers
    expect(response).to have_http_status(:unprocessable_content)

    patch api_watchlist_entry_path(entry), params: { fit_score: 6 }, headers: auth_headers
    expect(response).to have_http_status(:unprocessable_content)
    expect(json_body.fetch("message")).to include("Fit score")
  end
end
