require "rails_helper"

RSpec.describe UserSummarySerializer do
  it "serializes the shared four-field user representation" do
    user = create_user(role: "analyst")

    expect(described_class.call(user)).to eq(
      id: user.id,
      name: user.name,
      email: user.email,
      role: "analyst"
    )
  end

  it "returns nil when no user is present" do
    expect(described_class.call(nil)).to be_nil
  end
end
