require "rails_helper"

RSpec.describe User, type: :model do
  let(:password) { "a-secure-password" }

  it "uses the current PBKDF2 work factor for new passwords" do
    user = create_user(password: password)

    expect(user.password_iterations).to eq(described_class::PASSWORD_ITERATIONS)
    expect(user.authenticate_password(password)).to be(true)
    expect(user.authenticate_password("incorrect-password")).to be(false)
  end

  it "upgrades a legacy password hash after successful authentication" do
    user = create_user(password: password)
    set_legacy_password(user, password)

    expect { expect(user.authenticate_password(password)).to be(true) }
      .to change { user.reload.password_iterations }
      .from(described_class::LEGACY_PASSWORD_ITERATIONS)
      .to(described_class::PASSWORD_ITERATIONS)
    expect(user.authenticate_password(password)).to be(true)
  end

  it "does not upgrade a legacy hash after failed authentication" do
    user = create_user(password: password)
    set_legacy_password(user, password)

    expect(user.authenticate_password("incorrect-password")).to be(false)
    expect(user.reload.password_iterations).to eq(described_class::LEGACY_PASSWORD_ITERATIONS)
  end

  def set_legacy_password(user, value)
    legacy_salt = SecureRandom.hex(16)
    legacy_digest = OpenSSL::KDF.pbkdf2_hmac(
      value,
      salt: legacy_salt,
      iterations: described_class::LEGACY_PASSWORD_ITERATIONS,
      length: 32,
      hash: "SHA256"
    ).unpack1("H*")
    user.update_columns(
      password_salt: legacy_salt,
      password_digest: legacy_digest,
      password_iterations: described_class::LEGACY_PASSWORD_ITERATIONS
    )
  end
end
