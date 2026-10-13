class AdministratorBootstrap
  class AlreadyProvisionedError < StandardError; end

  ADVISORY_LOCK_NAME = "ninelens:users:bootstrap_admin".freeze

  Result = Data.define(:user, :created)

  def self.call(email:, name:, password:)
    new(email:, name:, password:).call
  end

  def initialize(email:, name:, password:)
    @email = email.to_s.strip.downcase
    @name = name.to_s.strip
    @password = password.to_s
  end

  def call
    User.transaction do
      acquire_advisory_lock

      existing_administrator = User.where(system_account: false, email: email).first
      return Result.new(user: existing_administrator, created: false) if existing_administrator&.admin?

      if User.where(system_account: false).exists?
        raise AlreadyProvisionedError,
          "A human account already exists. Create or promote administrators through the Admin user-management page."
      end

      user = User.create!(
        email: email,
        name: name,
        password: password,
        role: "administrator",
        system_account: false
      )

      Result.new(user: user, created: true)
    end
  end

  private

  attr_reader :email, :name, :password

  def acquire_advisory_lock
    return unless User.connection.adapter_name == "PostgreSQL"

    quoted_name = User.connection.quote(ADVISORY_LOCK_NAME)
    User.connection.execute("SELECT pg_advisory_xact_lock(hashtext(#{quoted_name}))")
  end
end
