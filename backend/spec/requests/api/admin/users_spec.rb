require "rails_helper"

RSpec.describe "Api::Admin::Users", type: :request do
  let(:administrator) { create_user(role: "administrator", name: "Admin User", email: "admin@example.test") }
  let(:headers) { user_headers(administrator) }

  it "requires an administrator and lists account status and managed roles" do
    scout = create_user(role: "scout", name: "Scout User")

    get api_admin_users_path, headers: headers

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("data").pluck("id")).to include(administrator.id, scout.id)
    expect(json_body.fetch("meta").fetch("roles").pluck("value")).to eq(
      %w[administrator analyst coach scout viewer]
    )

    get api_admin_users_path, headers: user_headers(scout)
    expect(response).to have_http_status(:forbidden)
  end

  it "lets an administrator create a user without replacing the administrator session" do
    post api_admin_users_path,
      params: { name: "New Analyst", email: "new.analyst@example.test", role: "analyst" },
      headers: headers

    expect(response).to have_http_status(:created)
    created = User.find_by!(email: "new.analyst@example.test")
    temporary_password = json_body.dig("data", "temporary_password")
    expect(created).to have_attributes(name: "New Analyst", role: "analyst")
    expect(created).to be_password_change_required
    expect(created.authenticate_password(temporary_password)).to be(true)
    expect(administrator.user_sessions.active).to exist

    audit = AuditLog.order(:id).last
    expect(audit).to have_attributes(user_id: administrator.id, action: "user_created",
      auditable_type: "User", auditable_id: created.id)
    expect(audit.change_set.to_s).not_to include(temporary_password)
  end

  it "rejects user creation by a non-administrator" do
    scout = create_user(role: "scout")

    post api_admin_users_path,
      params: { name: "No Access", email: "no.access@example.test", role: "viewer" },
      headers: user_headers(scout)

    expect(response).to have_http_status(:forbidden)
    expect(User.find_by(email: "no.access@example.test")).to be_nil
  end

  it "changes roles and records the administrator who made the change" do
    target = create_user(role: "viewer")

    patch api_admin_user_path(target), params: { role: "analyst" }, headers: headers

    expect(response).to have_http_status(:ok)
    expect(target.reload.role).to eq("analyst")
    audit = AuditLog.order(:id).last
    expect(audit).to have_attributes(user_id: administrator.id, action: "user_access_updated",
      auditable_type: "User", auditable_id: target.id)
    expect(audit.change_set).to include("role" => [ "viewer", "analyst" ])
  end

  it "disables and re-enables an account while revoking its active session" do
    target = create_user(role: "coach")
    target_headers = user_headers(target)

    patch api_admin_user_path(target), params: { disabled: true }, headers: headers

    expect(response).to have_http_status(:ok)
    expect(target.reload.disabled_at).to be_present
    expect(target.user_sessions.active).not_to exist

    get api_auth_me_path, headers: target_headers
    expect(response).to have_http_status(:unauthorized)

    patch api_admin_user_path(target), params: { disabled: false }, headers: headers
    expect(response).to have_http_status(:ok)
    expect(target.reload.disabled_at).to be_nil
  end

  it "resets access, revokes the old session, and returns a one-time password" do
    target = create_user(role: "scout")
    target_headers = user_headers(target)

    post reset_access_api_admin_user_path(target), headers: headers

    expect(response).to have_http_status(:ok)
    temporary_password = json_body.dig("data", "temporary_password")
    expect(temporary_password.length).to be >= 8
    expect(target.reload).to be_password_change_required
    expect(AuditLog.order(:id).last.change_set.to_s).not_to include(temporary_password)

    get api_auth_me_path, headers: target_headers
    expect(response).to have_http_status(:unauthorized)

    post api_auth_login_path, params: { email: target.email, password: temporary_password }
    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", "password_change_required")).to be(true)
  end

  it "protects the system account and prevents administrators from locking themselves out" do
    system_user = User.create!(
      email: "system@example.test",
      name: "System",
      password: "system-password",
      role: "admin",
      system_account: true
    )

    patch api_admin_user_path(system_user), params: { disabled: true }, headers: headers
    expect(response).to have_http_status(:forbidden)

    patch api_admin_user_path(administrator), params: { role: "viewer" }, headers: headers
    expect(response).to have_http_status(:unprocessable_content)
    expect(administrator.reload.role).to eq("administrator")

    post reset_access_api_admin_user_path(administrator), headers: headers
    expect(response).to have_http_status(:unprocessable_content)
  end
end
