require "rails_helper"

RSpec.describe "Offseason transactions API", type: :request do
  it "returns the full offseason moves list" do
    query = instance_double(OffseasonTransactionsQuery, result: {
      season: 2026, as_of: Date.new(2026, 11, 25),
      transactions: [ { id: "trade-1", type: "Trade", description: "A trade" } ]
    })
    allow(OffseasonTransactionsQuery).to receive(:new).with(on: ApplicationCalendar.current_date).and_return(query)

    get "/api/offseason_transactions"

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("data", "transactions", 0, "description")).to eq("A trade")
  end
end
