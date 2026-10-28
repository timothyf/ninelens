require "rails_helper"

RSpec.describe AuthenticationRateLimiter do
  before do
    stub_const("AuthenticationRateLimiter::POLICIES", {
      login_ip: { limit: 2, period: 15.minutes },
      login_account: { limit: 2, period: 15.minutes },
      registration_ip: { limit: 2, period: 1.hour },
      registration_account: { limit: 2, period: 1.hour }
    }.freeze)
  end

  it "allows requests up to the policy limit and then returns a retry interval" do
    first = described_class.consume(action: :login_account, identifier: "USER@example.test")
    second = described_class.consume(action: :login_account, identifier: "user@example.test")
    blocked = described_class.consume(action: :login_account, identifier: "user@example.test")

    expect(first).to have_attributes(allowed: true, retry_after: 0)
    expect(second).to have_attributes(allowed: true, retry_after: 0)
    expect(blocked.allowed).to be(false)
    expect(blocked.retry_after).to be_between(1, 15.minutes.to_i)
  end

  it "stores a keyed digest rather than the raw identifier" do
    described_class.consume(action: :login_ip, identifier: "203.0.113.42")

    record = AuthenticationRateLimit.last
    expect(record.identifier_digest).not_to include("203.0.113.42")
    expect(record.identifier_digest).to match(/\A[0-9a-f]{64}\z/)
  end

  it "reuses an existing counter without attempting another insert" do
    described_class.consume(action: :login_ip, identifier: "203.0.113.42")

    inserts = []
    subscriber = ->(*, payload) { inserts << payload[:sql] if payload[:sql].include?('INSERT INTO "authentication_rate_limits"') }
    result = ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      described_class.consume(action: :login_ip, identifier: "203.0.113.42")
    end

    expect(result.allowed).to be(true)
    expect(inserts).to be_empty
  end

  it "opens a new window after the previous window expires" do
    described_class.consume(action: :login_ip, identifier: "203.0.113.42")
    described_class.consume(action: :login_ip, identifier: "203.0.113.42")
    AuthenticationRateLimit.update_all(window_started_at: 16.minutes.ago)

    expect(described_class.consume(action: :login_ip, identifier: "203.0.113.42").allowed).to be(true)
  end

  it "can reset an account counter after successful authentication" do
    described_class.consume(action: :login_account, identifier: "user@example.test")
    described_class.consume(action: :login_account, identifier: "user@example.test")

    described_class.reset(action: :login_account, identifier: "user@example.test")

    expect(described_class.consume(action: :login_account, identifier: "user@example.test").allowed).to be(true)
  end
end
