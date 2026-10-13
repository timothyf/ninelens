require "rails_helper"

RSpec.describe "User sessions", type: :request do
  let(:user) { create_user(email: "member@example.test", password: "correct-password") }

  it "returns session expiry and accepts the token before expiration" do
    post api_auth_login_path, params: { email: user.email, password: "correct-password" }

    expect(response).to have_http_status(:ok)
    token = json_body.dig("data", "token")
    expires_at = Time.zone.parse(json_body.dig("data", "expires_at"))
    expect(expires_at).to be_within(5.seconds).of(12.hours.from_now)

    get api_auth_me_path, headers: { "Authorization" => "Bearer #{token}" }
    expect(response).to have_http_status(:ok)
  end

  it "rejects an expired session" do
    token = user.issue_auth_token!
    UserSession.find_by!(token_digest: UserSession.token_digest(token)).update!(expires_at: 1.minute.ago)

    get api_auth_me_path, headers: { "Authorization" => "Bearer #{token}" }

    expect(response).to have_http_status(:unauthorized)
  end

  it "revokes only the presented session on logout" do
    first_token = user.issue_auth_token!
    second_token = user.issue_auth_token!

    delete api_auth_logout_path, headers: { "Authorization" => "Bearer #{first_token}" }
    expect(response).to have_http_status(:no_content)

    get api_auth_me_path, headers: { "Authorization" => "Bearer #{first_token}" }
    expect(response).to have_http_status(:unauthorized)

    get api_auth_me_path, headers: { "Authorization" => "Bearer #{second_token}" }
    expect(response).to have_http_status(:ok)
  end
end
