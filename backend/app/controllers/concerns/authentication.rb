module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :load_current_user
  end

  private

  def current_user
    Current.user
  end

  def current_session
    Current.session
  end

  def require_authenticated_user
    return if current_user.present?

    render json: { message: "Authentication is required" }, status: :unauthorized
  end

  def require_admin_user
    return if current_user&.admin?

    render json: { message: "Administrator access is required" }, status: :forbidden
  end

  def require_read_access!(record)
    return if current_user&.admin? || record.owner_id == current_user&.id

    render json: { message: "You are not authorized to access this resource" }, status: :forbidden
  end

  def require_write_access!(record)
    return if current_user&.can_manage?(record)

    render json: { message: "You are not authorized to change this resource" }, status: :forbidden
  end

  def load_current_user
    Current.request_id = request.request_id
    token = request.authorization.to_s[/\ABearer\s+(.+)\z/i, 1].presence
    if token.present?
      session = UserSession.authenticate(token)
      if session&.user&.active_for_sign_in?
        Current.session = session
        Current.user = session.user
        session.mark_used!
      elsif admin_token_authenticated?
        Current.user = system_account_user
      end
    elsif admin_token_authenticated?
      Current.user = system_account_user
    end
  end

  def system_account_user
    User.active.find_by(system_account: true) || User.create!(
      email: "system@ninelens.local",
      name: "NineLens System",
      role: "admin",
      password: SecureRandom.urlsafe_base64(24),
      system_account: true
    )
  rescue ActiveRecord::RecordNotUnique
    User.active.find_by!(system_account: true)
  end

  def admin_token_authenticated?
    expected_token = ENV["ADMIN_API_TOKEN"].to_s
    submitted_token = request.authorization.to_s[/\ABearer\s+(.+)\z/i, 1].presence || request.headers["X-Admin-Token"].to_s
    return false if expected_token.blank? || submitted_token.blank?

    ActiveSupport::SecurityUtils.secure_compare(
      Digest::SHA256.hexdigest(submitted_token), Digest::SHA256.hexdigest(expected_token)
    )
  end
end
