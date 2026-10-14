require "rails_helper"

RSpec.describe "Production registration", type: :request do
  before do
    allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new("production"))
  end

  it "rejects anonymous registration even when no human account exists" do
    post api_auth_register_path,
      params: { email: "attacker@example.test", name: "Attacker", password: "password-123" }

    expect(response).to have_http_status(:forbidden)
    expect(json_body.fetch("message")).to eq(
      "Public registration is disabled. Ask an administrator to create your account."
    )
    expect(User.where(system_account: false)).not_to exist
  end

  it "still permits an authenticated administrator to create an account" do
    administrator = create_user(role: "administrator")

    post api_auth_register_path,
      params: { email: "viewer@example.test", name: "Viewer", password: "password-123" },
      headers: user_headers(administrator)

    expect(response).to have_http_status(:created)
    expect(User.find_by!(email: "viewer@example.test")).to have_attributes(role: "viewer")
  end
end
