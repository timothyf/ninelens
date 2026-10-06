require "rails_helper"

RSpec.describe "Authentication and watchlist ownership", type: :request do
  it "bootstraps a user, issues a token, and returns the current identity" do
    post api_auth_register_path, params: { email: "owner@example.test", name: "Owner", password: "password-123" }

    expect(response).to have_http_status(:created)
    token = json_body.dig("data", "token")
    expect(token).to be_present
    expect(json_body.dig("data", "role")).to eq("administrator")

    get api_admin_users_path, headers: { "Authorization" => "Bearer #{token}" }

    expect(response).to have_http_status(:ok)

    post api_auth_register_path,
      params: { email: "second@example.test", name: "Second User", password: "password-456" },
      headers: { "Authorization" => "Bearer #{token}" }

    expect(response).to have_http_status(:created)
    expect(json_body.dig("data", "role")).to eq("viewer")

    get api_auth_me_path, headers: { "Authorization" => "Bearer #{token}" }

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", "email")).to eq("owner@example.test")

    post api_auth_login_path, params: { email: "owner@example.test", password: "password-123" }

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", "token")).to be_present
  end

  it "requires authentication for private watchlists and isolates owners" do
    get api_watchlists_path
    expect(response).to have_http_status(:unauthorized)

    owner = create_user(role: "editor")
    other_user = create_user(role: "editor")
    watchlist = Watchlist.create!(name: "Private targets", owner: owner)

    get api_watchlists_path, headers: user_headers(other_user)
    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("data")).to eq([])

    get api_watchlist_path(watchlist), headers: user_headers(other_user)
    expect(response).to have_http_status(:not_found)
  end

  it "attributes mutations and exposes audit history to the owner" do
    owner = create_user(role: "editor")
    headers = user_headers(owner)
    post api_watchlists_path, params: { name: "Audited targets", description: "Private notes" }, headers: headers
    watchlist_id = json_body.dig("data", "id")

    patch api_watchlist_path(watchlist_id), params: { description: "Updated private notes" }, headers: headers
    expect(response).to have_http_status(:ok)

    get audit_history_api_watchlist_path(watchlist_id), headers: headers

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("data").map { |log| log.fetch("action") }).to include("created", "updated")
    expect(json_body.dig("data", 0, "user", "id")).to eq(owner.id)
  end

  it "lets viewers read owned resources but not change them" do
    viewer = create_user(role: "viewer")
    watchlist = Watchlist.create!(name: "Read only", owner: viewer)

    patch api_watchlist_path(watchlist), params: { description: "Attempted change" }, headers: user_headers(viewer)

    expect(response).to have_http_status(:forbidden)
  end
end
