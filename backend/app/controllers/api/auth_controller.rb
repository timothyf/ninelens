module Api
  class AuthController < ApplicationController
    skip_before_action :authenticate_unsafe_api_request

    def register
      if User.where(system_account: false).exists? && !current_user&.admin?
        return render json: { message: "Only an administrator can create additional users" }, status: :forbidden
      end

      user = User.new(user_params)
      user.role = if first_human_user?
        "administrator"
      elsif !current_user&.admin?
        "viewer"
      else
        user.role.presence || "viewer"
      end
      user.save!
      render json: { data: issue_session(user) }, status: :created
    rescue ActiveRecord::RecordInvalid => error
      render json: { message: error.record.errors.full_messages.to_sentence }, status: :unprocessable_content
    end

    def login
      user = User.active.find_by(email: params[:email].to_s.strip.downcase)
      return render json: { message: "Invalid email or password" }, status: :unauthorized unless user&.authenticate_password(params[:password])

      render json: { data: issue_session(user) }
    end

    def me
      require_authenticated_user
      return if performed?

      render json: { data: serialize_user(current_user) }
    end

    def logout
      current_user&.revoke_auth_token!
      head :no_content
    end

    private

    def user_params
      params.permit(:email, :name, :password, :role)
    end

    def first_human_user?
      !User.where(system_account: false).exists?
    end

    def issue_session(user)
      token = user.issue_auth_token!
      AuditLog.record!(user: user, action: "signed_in", record: user, metadata: { "request_id" => request.request_id })
      serialize_user(user).merge(token: token)
    end

    def serialize_user(user)
      { id: user.id, email: user.email, name: user.name, role: user.role, role_label: user.role_label }
    end
  end
end
