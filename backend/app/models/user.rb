class User < ApplicationRecord
  ROLES = %w[administrator analyst coach scout viewer admin editor].freeze
  LEGACY_PASSWORD_ITERATIONS = 120_000
  PASSWORD_ITERATIONS = 600_000

  has_many :owned_watchlists, class_name: "Watchlist", foreign_key: :owner_id, dependent: :nullify
  has_many :owned_need_profiles, class_name: "NeedProfile", foreign_key: :owner_id, dependent: :nullify
  has_many :owned_lineup_scenarios, class_name: "LineupScenario", foreign_key: :owner_id, dependent: :restrict_with_error
  has_many :owned_opponent_reports, class_name: "OpponentReport", foreign_key: :owner_id, dependent: :restrict_with_error
  has_many :saved_analyses, foreign_key: :owner_id, dependent: :destroy
  has_many :authored_notes, class_name: "Note", foreign_key: :author_id, dependent: :restrict_with_error
  has_many :note_revisions, foreign_key: :editor_id, dependent: :restrict_with_error
  has_many :created_tags, class_name: "Tag", foreign_key: :created_by_id, dependent: :restrict_with_error
  has_many :audit_logs, dependent: :nullify
  has_many :alert_subscriptions, dependent: :destroy
  has_many :alerts, dependent: :destroy
  has_many :assigned_alerts, class_name: "Alert", foreign_key: :assigned_to_id, dependent: :nullify
  has_many :user_sessions, dependent: :destroy

  validates :email, presence: true, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true
  validates :role, inclusion: { in: ROLES }
  validates :alert_digest_frequency, inclusion: { in: %w[off daily weekly] }, if: -> { respond_to?(:alert_digest_frequency) }
  validates :alert_digest_day, numericality: { only_integer: true, in: 0..6 }, allow_nil: true, if: -> { respond_to?(:alert_digest_day) }
  validates :alert_digest_hour, numericality: { only_integer: true, in: 0..23 }, if: -> { respond_to?(:alert_digest_hour) }
  validates :password, length: { minimum: 8 }, allow_nil: true

  scope :active, -> { where(disabled_at: nil) }

  attr_reader :password

  before_validation :normalize_email

  def password=(value)
    @password = value.to_s
    self.password_salt = SecureRandom.hex(16)
    self.password_iterations = PASSWORD_ITERATIONS
    self.password_digest = digest_password(@password, password_salt, iterations: password_iterations)
  end

  def authenticate_password(value)
    return false if password_digest.blank? || password_salt.blank?

    candidate_password = value.to_s
    authenticated = ActiveSupport::SecurityUtils.secure_compare(
      digest_password(candidate_password, password_salt, iterations: effective_password_iterations),
      password_digest
    )
    upgrade_password_hash!(candidate_password) if authenticated && effective_password_iterations < PASSWORD_ITERATIONS
    authenticated
  end

  def issue_session!
    UserSession.issue_for!(user: self)
  end

  def issue_auth_token!
    issue_session!.token
  end

  def revoke_all_sessions!
    user_sessions.active.update_all(revoked_at: Time.current, updated_at: Time.current)
  end

  def revoke_other_sessions!(session)
    user_sessions.active.where.not(id: session&.id).update_all(revoked_at: Time.current, updated_at: Time.current)
  end

  def admin?
    role.in?(%w[admin administrator])
  end

  def active_for_sign_in?
    disabled_at.nil?
  end

  def can_write?
    admin? || role.in?(%w[analyst coach scout editor])
  end

  def role_label
    { "admin" => "Administrator", "editor" => "Scout" }.fetch(role, role.to_s.titleize)
  end

  def can_manage?(record)
    admin? || (can_write? && record.respond_to?(:owner_id) && record.owner_id == id)
  end

  private

  def effective_password_iterations
    password_iterations.presence || LEGACY_PASSWORD_ITERATIONS
  end

  def digest_password(value, salt, iterations:)
    OpenSSL::KDF.pbkdf2_hmac(value, salt: salt, iterations: iterations, length: 32, hash: "SHA256").unpack1("H*")
  end

  def upgrade_password_hash!(value)
    previous_digest = password_digest
    previous_salt = password_salt
    previous_iterations = effective_password_iterations
    upgraded_salt = SecureRandom.hex(16)
    upgraded_digest = digest_password(value, upgraded_salt, iterations: PASSWORD_ITERATIONS)
    now = Time.current

    upgraded = self.class.where(
      id: id,
      password_digest: previous_digest,
      password_salt: previous_salt,
      password_iterations: previous_iterations
    ).update_all(
      password_digest: upgraded_digest,
      password_salt: upgraded_salt,
      password_iterations: PASSWORD_ITERATIONS,
      updated_at: now
    )
    return unless upgraded == 1

    self.password_digest = upgraded_digest
    self.password_salt = upgraded_salt
    self.password_iterations = PASSWORD_ITERATIONS
    self.updated_at = now
  end

  def normalize_email
    self.email = email.to_s.strip.downcase
  end
end
