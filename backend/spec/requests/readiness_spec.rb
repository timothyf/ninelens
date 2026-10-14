require "rails_helper"

RSpec.describe "Readiness", type: :request do
  it "reports the application and database as ready" do
    get rails_health_check_path

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/json")
    expect(response.headers.fetch("Cache-Control")).to include("no-store")
    expect(json_body).to eq(
      "status" => "ok",
      "checks" => {
        "application" => "ok",
        "database" => "ok"
      }
    )
  end

  it "reports service unavailable without exposing database error details" do
    allow(ActiveRecord::Base.connection_pool).to receive(:with_connection)
      .and_raise(ActiveRecord::ConnectionNotEstablished, "secret connection details")

    get rails_health_check_path

    expect(response).to have_http_status(:service_unavailable)
    expect(response.headers.fetch("Cache-Control")).to include("no-store")
    expect(response.body).not_to include("secret connection details")
    expect(json_body).to eq(
      "status" => "unavailable",
      "checks" => {
        "application" => "ok",
        "database" => "unavailable"
      }
    )
  end
end
