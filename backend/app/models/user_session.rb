class UserSession < ApplicationRecord
  DEFAULT_TTL_HOURS = 12
  LAST_USED_TOUCH_INTERVAL = 5.minutes

  IssuedSession = Data.define(:session, :token)

  belongs_to :user

  validates :token_digest, presence: true, uniqueness: true
  validates :expires_at, presence: true

  scope :active, -> { where(revoked_at: nil).where("expires_at > ?", Time.current) }
  scope :stale, lambda {
    cutoff = 30.days.ago
    where("expires_at < :cutoff OR revoked_at < :cutoff", cutoff:)
  }

  def self.issue_for!(user:)
    raw_token = SecureRandom.urlsafe_base64(48)
    session = create!(
      user:,
      token_digest: token_digest(raw_token),
      expires_at: session_ttl.from_now,
      last_used_at: Time.current
    )
    IssuedSession.new(session:, token: raw_token)
  end

  def self.authenticate(raw_token)
    return if raw_token.blank?

    active.includes(:user).find_by(token_digest: token_digest(raw_token))
  end

  def self.token_digest(raw_token)
    Digest::SHA256.hexdigest(raw_token.to_s)
  end

  def self.session_ttl
    configured_hours = Integer(ENV.fetch("USER_SESSION_TTL_HOURS", DEFAULT_TTL_HOURS), exception: false)
    (configured_hours&.positive? ? configured_hours : DEFAULT_TTL_HOURS).hours
  end

  def revoke!
    update!(revoked_at: Time.current) unless revoked_at?
  end

  def mark_used!
    return if last_used_at.present? && last_used_at > LAST_USED_TOUCH_INTERVAL.ago

    touch(:last_used_at)
  end
end
