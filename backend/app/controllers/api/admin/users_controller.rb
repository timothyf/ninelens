module Api
  module Admin
    class UsersController < ApplicationController
      MANAGED_ROLES = %w[administrator analyst coach scout viewer].freeze

      before_action :require_authenticated_user
      before_action :require_admin_user
      before_action :set_user, only: %i[update reset_access]

      def index
        users = User.order(system_account: :desc, name: :asc, email: :asc)

        render json: {
          data: users.map { |user| serialize_user(user) },
          meta: {
            active_count: users.count(&:active_for_sign_in?),
            disabled_count: users.count { |user| !user.active_for_sign_in? },
            administrator_count: users.count { |user| user.admin? && user.active_for_sign_in? && !user.system_account? },
            roles: MANAGED_ROLES.map { |role| { value: role, label: role.titleize } }
          }
        }
      end

      def create
        role = create_user_params[:role].presence || "viewer"
        validate_role!(role)
        return if performed?

        temporary_password = SecureRandom.urlsafe_base64(15)
        user = User.new(create_user_params.except(:role).merge(role:, password: temporary_password))
        user.save!

        AuditLog.record!(
          user: current_user,
          action: "user_created",
          record: user,
          changes: user.saved_changes.except("password_digest", "password_salt"),
          metadata: { "request_id" => request.request_id }
        )

        render json: {
          data: serialize_user(user).merge(temporary_password: temporary_password),
          meta: { message: "Share this temporary password securely; it is shown only once." }
        }, status: :created
      rescue ActiveRecord::RecordInvalid => error
        render json: { message: error.record.errors.full_messages.to_sentence }, status: :unprocessable_content
      end

      def update
        reject_system_account!
        return if performed?

        requested_role = user_params[:role].presence
        requested_disabled = user_params.key?(:disabled) ? ActiveModel::Type::Boolean.new.cast(user_params[:disabled]) : nil
        if requested_role.nil? && requested_disabled.nil?
          return render json: { message: "Provide a role or disabled status to update" }, status: :unprocessable_content
        end

        validate_role!(requested_role) if requested_role
        return if performed?

        prevent_self_lockout!(requested_role:, requested_disabled:)
        return if performed?

        prevent_last_admin_lockout!(requested_role:, requested_disabled:)
        return if performed?

        changes = {}
        changes[:role] = requested_role if requested_role
        changes[:disabled_at] = requested_disabled ? Time.current : nil unless requested_disabled.nil?

        @user.transaction do
          @user.update!(changes)
          @user.revoke_all_sessions! if requested_disabled
        end

        AuditLog.record!(
          user: current_user,
          action: "user_access_updated",
          record: @user,
          changes: @user.saved_changes.except("password_digest", "password_salt"),
          metadata: { "request_id" => request.request_id }
        )

        render json: { data: serialize_user(@user) }
      rescue ActiveRecord::RecordInvalid => error
        render json: { message: error.record.errors.full_messages.to_sentence }, status: :unprocessable_content
      end

      def reset_access
        reject_system_account!
        return if performed?
        if @user.id == current_user.id
          return render json: { message: "You cannot reset access for your current account" }, status: :unprocessable_content
        end

        temporary_password = SecureRandom.urlsafe_base64(15)
        @user.transaction do
          @user.update!(password: temporary_password)
          @user.revoke_all_sessions!
        end

        AuditLog.record!(
          user: current_user,
          action: "user_access_reset",
          record: @user,
          changes: { "session_access" => [ "active", "revoked" ] },
          metadata: { "request_id" => request.request_id }
        )

        render json: {
          data: serialize_user(@user).merge(temporary_password: temporary_password),
          meta: { message: "Existing sessions were revoked. Share this temporary password securely; it is shown only once." }
        }
      end

      private

      def set_user
        @user = User.find(params[:id])
      end

      def user_params
        params.permit(:role, :disabled)
      end

      def create_user_params
        params.permit(:name, :email, :role)
      end

      def validate_role!(role)
        return if role.in?(MANAGED_ROLES)

        render json: { message: "Role must be one of: #{MANAGED_ROLES.join(', ')}" }, status: :unprocessable_content
      end

      def reject_system_account!
        return unless @user.system_account?

        render json: { message: "The system automation account cannot be changed" }, status: :forbidden
      end

      def prevent_self_lockout!(requested_role:, requested_disabled:)
        return unless @user.id == current_user.id
        return unless requested_disabled || (requested_role.present? && requested_role != "administrator")

        render json: { message: "You cannot disable or remove administrator access from your own account" }, status: :unprocessable_content
      end

      def prevent_last_admin_lockout!(requested_role:, requested_disabled:)
        removes_admin = @user.admin? && (requested_disabled || (requested_role.present? && requested_role != "administrator"))
        return unless removes_admin

        other_admin_exists = User.active
          .where(system_account: false, role: %w[admin administrator])
          .where.not(id: @user.id)
          .exists?
        return if other_admin_exists

        render json: { message: "At least one active human administrator is required" }, status: :unprocessable_content
      end

      def serialize_user(user)
        {
          id: user.id,
          name: user.name,
          email: user.email,
          role: canonical_role(user.role),
          role_label: user.role_label,
          disabled: !user.active_for_sign_in?,
          disabled_at: user.disabled_at,
          last_signed_in_at: user.last_signed_in_at,
          system_account: user.system_account?,
          current_user: user.id == current_user.id,
          created_at: user.created_at,
          updated_at: user.updated_at
        }
      end

      def canonical_role(role)
        { "admin" => "administrator", "editor" => "scout" }.fetch(role, role)
      end
    end
  end
end
