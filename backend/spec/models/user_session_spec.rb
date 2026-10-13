require "rails_helper"

RSpec.describe UserSession, type: :model do
  let(:user) { create_user }

  def with_session_ttl(value)
    previous_value = ENV["USER_SESSION_TTL_HOURS"]
    ENV["USER_SESSION_TTL_HOURS"] = value
    yield
  ensure
    previous_value.nil? ? ENV.delete("USER_SESSION_TTL_HOURS") : ENV["USER_SESSION_TTL_HOURS"] = previous_value
  end

  it "issues a hashed, expiring token" do
    issued = described_class.issue_for!(user:)

    expect(issued.token).to be_present
    expect(issued.session).to have_attributes(user:, revoked_at: nil)
    expect(issued.session.token_digest).to eq(Digest::SHA256.hexdigest(issued.token))
    expect(issued.session.token_digest).not_to eq(issued.token)
    expect(issued.session.expires_at).to be_within(5.seconds).of(12.hours.from_now)
  end

  it "authenticates only unexpired, unrevoked sessions" do
    active = described_class.issue_for!(user:)
    expired = described_class.issue_for!(user:)
    revoked = described_class.issue_for!(user:)
    expired.session.update!(expires_at: 1.minute.ago)
    revoked.session.revoke!

    expect(described_class.authenticate(active.token)).to eq(active.session)
    expect(described_class.authenticate(expired.token)).to be_nil
    expect(described_class.authenticate(revoked.token)).to be_nil
  end

  it "uses the configured positive session lifetime and falls back for invalid values" do
    with_session_ttl("24") do
      expect(described_class.session_ttl).to eq(24.hours)
    end

    with_session_ttl("invalid") do
      expect(described_class.session_ttl).to eq(12.hours)
    end
  end
end
