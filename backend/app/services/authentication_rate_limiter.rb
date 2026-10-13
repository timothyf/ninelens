class AuthenticationRateLimiter
  Result = Data.define(:allowed, :retry_after)

  POLICIES = {
    login_ip: { limit: 30, period: 15.minutes },
    login_account: { limit: 10, period: 15.minutes },
    registration_ip: { limit: 5, period: 1.hour },
    registration_account: { limit: 3, period: 1.hour }
  }.freeze

  def self.consume(action:, identifier:)
    new(action:, identifier:).consume
  end

  def self.reset(action:, identifier:)
    AuthenticationRateLimit.where(
      action: action.to_s,
      identifier_digest: identifier_digest(identifier)
    ).delete_all
  end

  def self.identifier_digest(identifier)
    normalized_identifier = identifier.to_s.strip.downcase.presence || "<blank>"
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, normalized_identifier)
  end

  def initialize(action:, identifier:)
    @action = action.to_sym
    @identifier = identifier
  end

  def consume
    policy = POLICIES.fetch(action)
    now = Time.current
    rate_limit = find_or_create_rate_limit(now)

    rate_limit.with_lock do
      reset_window(rate_limit, now) if window_expired?(rate_limit, now, policy[:period])

      if rate_limit.attempt_count >= policy[:limit]
        return Result.new(
          allowed: false,
          retry_after: retry_after(rate_limit, now, policy[:period])
        )
      end

      rate_limit.update!(attempt_count: rate_limit.attempt_count + 1)
      Result.new(allowed: true, retry_after: 0)
    end
  end

  private

  attr_reader :action, :identifier

  def find_or_create_rate_limit(now)
    AuthenticationRateLimit.create_or_find_by!(
      action: action.to_s,
      identifier_digest: self.class.identifier_digest(identifier)
    ) do |rate_limit|
      rate_limit.window_started_at = now
      rate_limit.attempt_count = 0
    end
  end

  def window_expired?(rate_limit, now, period)
    rate_limit.window_started_at <= now - period
  end

  def reset_window(rate_limit, now)
    rate_limit.update!(window_started_at: now, attempt_count: 0)
  end

  def retry_after(rate_limit, now, period)
    [ (rate_limit.window_started_at + period - now).ceil, 1 ].max
  end
end
