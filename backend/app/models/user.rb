class User < ApplicationRecord
  ROLES = %w[administrator analyst coach scout viewer admin editor].freeze
  PASSWORD_ITERATIONS = 120_000

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

  validates :email, presence: true, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true
  validates :role, inclusion: { in: ROLES }
  validates :alert_digest_frequency, inclusion: { in: %w[off daily weekly] }, if: -> { respond_to?(:alert_digest_frequency) }
  validates :alert_digest_day, numericality: { only_integer: true, in: 0..6 }, allow_nil: true, if: -> { respond_to?(:alert_digest_day) }
  validates :alert_digest_hour, numericality: { only_integer: true, in: 0..23 }, if: -> { respond_to?(:alert_digest_hour) }
  validates :password, length: { minimum: 8 }, allow_nil: true, on: :create

  scope :active, -> { where(disabled_at: nil) }

  attr_reader :password

  before_validation :normalize_email

  def password=(value)
    @password = value.to_s
    self.password_salt = SecureRandom.hex(16)
    self.password_digest = digest_password(@password, password_salt)
  end

  def authenticate_password(value)
    return false if password_digest.blank? || password_salt.blank?

    ActiveSupport::SecurityUtils.secure_compare(
      digest_password(value.to_s, password_salt), password_digest
    )
  end

  def issue_auth_token!
    raw_token = SecureRandom.urlsafe_base64(48)
    update!(auth_token_digest: Digest::SHA256.hexdigest(raw_token))
    raw_token
  end

  def revoke_auth_token!
    update!(auth_token_digest: nil)
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

  def digest_password(value, salt)
    OpenSSL::KDF.pbkdf2_hmac(value, salt: salt, iterations: PASSWORD_ITERATIONS, length: 32, hash: "SHA256").unpack1("H*")
  end

  def normalize_email
    self.email = email.to_s.strip.downcase
  end
end
