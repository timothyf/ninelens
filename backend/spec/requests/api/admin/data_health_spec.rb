require "rails_helper"

RSpec.describe "Api::Admin::DataHealth", type: :request do
  around { |example| with_admin_api_token("test-admin-token", &example) }
  before { allow(MlbTotalsReconciliation).to receive(:call).and_return([]) }
  it "returns the current data-health report" do
    get api_admin_data_health_path, headers: admin_headers

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("data")).to include(
      "status",
      "checked_at",
      "calculation_version",
      "summary",
      "checks"
    )
    expect(json_body.dig("data", "include_postseason")).to be(true)
    expect(json_body.dig("data", "summary")).to include(
      "check_count" => 13,
      "healthy_count" => be_a(Integer),
      "warning_count" => be_a(Integer),
      "critical_count" => be_a(Integer),
      "affected_record_count" => be_a(Integer)
    )
    expect(json_body.dig("data", "checks").first).to include(
      "id",
      "category",
      "name",
      "status",
      "affected_count",
      "description",
      "recommendation",
      "examples"
    )
  end

  it "passes the postseason selection to the health check" do
    get api_admin_data_health_path, params: { include_postseason: false }, headers: admin_headers

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", "include_postseason")).to be(false)
  end
end
