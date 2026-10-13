require "rails_helper"

RSpec.describe "Authentication throttling", type: :request do
  before do
    stub_const("AuthenticationRateLimiter::POLICIES", {
      login_ip: { limit: 2, period: 15.minutes },
      login_account: { limit: 2, period: 15.minutes },
      registration_ip: { limit: 2, period: 1.hour },
      registration_account: { limit: 2, period: 1.hour }
    }.freeze)
  end

  it "throttles repeated login attempts for an account across IP addresses" do
    2.times do |index|
      post api_auth_login_path,
        params: { email: "target@example.test", password: "incorrect" },
        headers: { "REMOTE_ADDR" => "203.0.113.#{index + 1}" }
      expect(response).to have_http_status(:unauthorized)
    end

    post api_auth_login_path,
      params: { email: "TARGET@example.test", password: "incorrect" },
      headers: { "REMOTE_ADDR" => "203.0.113.99" }

    expect(response).to have_http_status(:too_many_requests)
    expect(response.headers["Retry-After"].to_i).to be_positive
    expect(json_body.fetch("message")).to eq("Too many authentication attempts. Try again later.")
  end

  it "throttles login attempts from one IP across account names" do
    2.times do |index|
      post api_auth_login_path,
        params: { email: "target#{index}@example.test", password: "incorrect" },
        headers: { "REMOTE_ADDR" => "203.0.113.42" }
      expect(response).to have_http_status(:unauthorized)
    end

    post api_auth_login_path,
      params: { email: "another@example.test", password: "incorrect" },
      headers: { "REMOTE_ADDR" => "203.0.113.42" }

    expect(response).to have_http_status(:too_many_requests)
  end

  it "throttles repeated registration attempts for an account across IP addresses" do
    existing_user = create_user(role: "administrator")
    headers = user_headers(existing_user).merge("REMOTE_ADDR" => "203.0.113.50")

    2.times do
      post api_auth_register_path,
        params: { email: "new-user@example.test", name: "New User", password: "password-123" },
        headers: headers
      expect(response).to have_http_status(:created).or have_http_status(:unprocessable_content)
    end

    post api_auth_register_path,
      params: { email: "new-user@example.test", name: "New User", password: "password-123" },
      headers: headers.merge("REMOTE_ADDR" => "203.0.113.51")

    expect(response).to have_http_status(:too_many_requests)
  end

  it "throttles registration attempts from one IP across account names" do
    administrator = create_user(role: "administrator")
    headers = user_headers(administrator).merge("REMOTE_ADDR" => "203.0.113.55")

    2.times do |index|
      post api_auth_register_path,
        params: { email: "new-user-#{index}@example.test", name: "New User", password: "password-123" },
        headers: headers
      expect(response).to have_http_status(:created)
    end

    post api_auth_register_path,
      params: { email: "another-user@example.test", name: "Another User", password: "password-123" },
      headers: headers

    expect(response).to have_http_status(:too_many_requests)
  end

  it "clears the account counter after a successful login" do
    user = create_user(email: "member@example.test", password: "correct-password")

    post api_auth_login_path,
      params: { email: user.email, password: "incorrect" },
      headers: { "REMOTE_ADDR" => "203.0.113.60" }
    post api_auth_login_path,
      params: { email: user.email, password: "correct-password" },
      headers: { "REMOTE_ADDR" => "203.0.113.61" }
    expect(response).to have_http_status(:ok)

    2.times do |index|
      post api_auth_login_path,
        params: { email: user.email, password: "incorrect" },
        headers: { "REMOTE_ADDR" => "203.0.113.#{70 + index}" }
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
