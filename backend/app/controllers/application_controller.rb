class ApplicationController < ActionController::API
  include Authentication
  before_action :authenticate_unsafe_api_request
  before_action :require_completed_password_change

  private

  def require_completed_password_change
    return unless current_user&.password_change_required?

    render json: {
      message: "You must replace your temporary password before continuing.",
      code: "password_change_required"
    }, status: :forbidden
  end

  def authenticate_unsafe_api_request
    return if safe_api_request?
    return if current_user&.admin?

    expected_token = ENV["ADMIN_API_TOKEN"].to_s
    return if expected_token.blank? && !Rails.env.production?

    unless expected_token.present? && admin_token_matches?(expected_token)
      render json: { message: "Admin API token is required" }, status: :unauthorized
    end
  end

  def safe_api_request?
    request.get? || request.head? || request.request_method == "OPTIONS"
  end

  def admin_token_matches?(expected_token)
    submitted_token = request_admin_token
    return false if submitted_token.blank?

    ActiveSupport::SecurityUtils.secure_compare(
      Digest::SHA256.hexdigest(submitted_token),
      Digest::SHA256.hexdigest(expected_token)
    )
  end

  def request_admin_token
    bearer_token = request.authorization.to_s[/\ABearer\s+(.+)\z/i, 1]
    bearer_token.presence || request.headers["X-Admin-Token"].to_s
  end
end
