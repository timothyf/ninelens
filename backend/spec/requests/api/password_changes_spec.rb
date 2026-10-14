require "rails_helper"

RSpec.describe "Password changes", type: :request do
  let(:temporary_password) { "temporary-password-123" }
  let(:new_password) { "replacement-password-456" }
  let(:user) do
    create_user(
      email: "new.user@example.test",
      password: temporary_password,
      password_change_required: true
    )
  end

  it "requires a signed-in user" do
    patch api_auth_password_path, params: password_params

    expect(response).to have_http_status(:unauthorized)
  end

  it "does not let the automation token change a user's password" do
    with_admin_api_token("automation-token") do
      patch api_auth_password_path,
        params: password_params,
        headers: { "Authorization" => "Bearer automation-token" }
    end

    expect(response).to have_http_status(:unauthorized)
    expect(json_body.fetch("message")).to eq("A user session is required")
  end

  it "blocks application access until the temporary password is replaced" do
    headers = user_headers(user)

    get api_home_path, headers: headers

    expect(response).to have_http_status(:forbidden)
    expect(json_body).to include(
      "code" => "password_change_required",
      "message" => "You must replace your temporary password before continuing."
    )

    get api_auth_me_path, headers: headers
    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", "password_change_required")).to be(true)
  end

  it "replaces the password, clears the requirement, and revokes other sessions" do
    current_session = user.issue_session!
    other_session = user.issue_session!

    patch api_auth_password_path,
      params: password_params,
      headers: { "Authorization" => "Bearer #{current_session.token}" }

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", "password_change_required")).to be(false)
    expect(user.reload).not_to be_password_change_required
    expect(user.authenticate_password(new_password)).to be(true)
    expect(UserSession.authenticate(current_session.token)).to be_present
    expect(UserSession.authenticate(other_session.token)).to be_nil
    expect(AuditLog.order(:id).last).to have_attributes(user_id: user.id, action: "password_changed")
  end

  it "rejects an incorrect current password, a mismatch, and password reuse" do
    headers = user_headers(user)

    patch api_auth_password_path, params: password_params(current_password: "incorrect-password"), headers: headers
    expect(response).to have_http_status(:unprocessable_content)
    expect(json_body.fetch("message")).to eq("Current password is incorrect")

    patch api_auth_password_path, params: password_params(password_confirmation: "different-password"), headers: headers
    expect(response).to have_http_status(:unprocessable_content)
    expect(json_body.fetch("message")).to eq("Password confirmation does not match")

    patch api_auth_password_path,
      params: password_params(password: temporary_password, password_confirmation: temporary_password),
      headers: headers
    expect(response).to have_http_status(:unprocessable_content)
    expect(json_body.fetch("message")).to eq("New password must be different from your current password")
    expect(user.reload).to be_password_change_required
  end

  private

  def password_params(overrides = {})
    {
      current_password: temporary_password,
      password: new_password,
      password_confirmation: new_password
    }.merge(overrides)
  end
end
