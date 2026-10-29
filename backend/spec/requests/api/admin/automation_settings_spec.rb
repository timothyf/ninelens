require "rails_helper"

RSpec.describe "Api::Admin::AutomationSettings", type: :request do
  let(:administrator) { create_user(role: "administrator") }
  let(:headers) { user_headers(administrator) }

  it "shows the enabled state to administrators and rejects other users" do
    get api_admin_automation_setting_path, headers: headers
    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("data")).to include("enabled" => true, "interval_minutes" => 15)

    get api_admin_automation_setting_path, headers: user_headers(create_user(role: "viewer"))
    expect(response).to have_http_status(:forbidden)
  end

  it "persists changes and audits the administrator" do
    patch api_admin_automation_setting_path, params: { enabled: false }, headers: headers, as: :json

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", "enabled")).to be(false)
    setting = AutomationSetting.game_details_sync
    expect(setting.reload).not_to be_enabled
    expect(AuditLog.order(:id).last).to have_attributes(
      user_id: administrator.id,
      action: "automation_setting_updated",
      auditable_type: "AutomationSetting",
      auditable_id: setting.id,
      change_set: { "enabled" => [ true, false ] }
    )

    expect do
      patch api_admin_automation_setting_path, params: { enabled: false }, headers: headers, as: :json
    end.not_to change(AuditLog, :count)
  end

  it "updates the interval without changing the enabled state" do
    patch api_admin_automation_setting_path, params: { interval_minutes: 45 }, headers: headers, as: :json

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("data")).to include("enabled" => true, "interval_minutes" => 45)
    expect(AutomationSetting.game_details_sync.reload.interval_minutes).to eq(45)
    expect(AuditLog.order(:id).last.change_set).to include("interval_minutes" => [15, 45])
  end

  it "rejects invalid changes and non-administrators" do
    patch api_admin_automation_setting_path, params: { enabled: "maybe" }, headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_content)

    patch api_admin_automation_setting_path, params: { interval_minutes: 4 }, headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_content)

    patch api_admin_automation_setting_path, params: { enabled: false },
      headers: user_headers(create_user(role: "viewer")), as: :json
    expect(response).to have_http_status(:forbidden)
    expect(AutomationSetting.game_details_sync).to be_enabled
  end
end
