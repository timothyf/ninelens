require "rails_helper"

RSpec.describe AdministratorBootstrap do
  let(:attributes) do
    {
      email: "  OWNER@EXAMPLE.TEST ",
      name: "Workspace Owner",
      password: "a-secure-bootstrap-password"
    }
  end

  it "creates the first human account as an administrator" do
    result = described_class.call(**attributes)

    expect(result.created).to be(true)
    expect(result.user).to have_attributes(
      email: "owner@example.test",
      name: "Workspace Owner",
      role: "administrator",
      system_account: false
    )
    expect(result.user.authenticate_password(attributes[:password])).to be(true)
  end

  it "is idempotent without changing the existing administrator or password" do
    first_result = described_class.call(**attributes)
    original_digest = first_result.user.password_digest
    create_user(role: "viewer", email: "viewer@example.test")

    second_result = described_class.call(**attributes.merge(password: "a-different-secure-password"))

    expect(second_result.created).to be(false)
    expect(second_result.user).to eq(first_result.user)
    expect(second_result.user.reload.password_digest).to eq(original_digest)
    expect(User.where(system_account: false, role: "administrator").count).to eq(1)
  end

  it "refuses to bootstrap a different administrator after a human account exists" do
    create_user(role: "viewer", email: "viewer@example.test")

    expect { described_class.call(**attributes) }
      .to raise_error(described_class::AlreadyProvisionedError, /human account already exists/i)
    expect(User.find_by(email: "owner@example.test")).to be_nil
  end

  it "does not treat the internal system account as a human account" do
    User.create!(
      email: "system@example.test",
      name: "System",
      password: "system-password",
      role: "admin",
      system_account: true
    )

    expect { described_class.call(**attributes) }
      .to change { User.where(system_account: false, role: "administrator").count }.from(0).to(1)
  end

  it "uses normal user validations for the bootstrap credentials" do
    expect { described_class.call(**attributes.merge(password: "short")) }
      .to raise_error(ActiveRecord::RecordInvalid, /Password is too short/)
  end
end
