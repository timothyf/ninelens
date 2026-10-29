module Api
  module Admin
    class AutomationSettingsController < ApplicationController
      before_action :require_authenticated_user
      before_action :require_admin_user

      def show
        render json: { data: serialize(AutomationSetting.game_details_sync) }
      end

      def update
        unless params.key?(:enabled) || params.key?(:interval_minutes)
          return render json: { message: "Provide enabled or interval_minutes" }, status: :unprocessable_content
        end
        if params.key?(:enabled) && ![ true, false ].include?(params[:enabled])
          return render json: { message: "Enabled must be true or false" }, status: :unprocessable_content
        end
        if params.key?(:interval_minutes) && (!params[:interval_minutes].is_a?(Integer) || !params[:interval_minutes].between?(5, 1440))
          return render json: { message: "Interval must be between 5 and 1440 minutes" }, status: :unprocessable_content
        end

        setting = AutomationSetting.game_details_sync
        setting.with_lock do
          changes = {}
          changes["enabled"] = [setting.enabled?, params[:enabled]] if params.key?(:enabled) && setting.enabled? != params[:enabled]
          if params.key?(:interval_minutes) && setting.interval_minutes != params[:interval_minutes]
            changes["interval_minutes"] = [setting.interval_minutes, params[:interval_minutes]]
          end
          if changes.any?
            setting.update!(changes.transform_values(&:last))
            AuditLog.record!(
              user: current_user,
              action: "automation_setting_updated",
              record: setting,
              changes: changes,
              metadata: { "request_id" => request.request_id }
            )
          end
        end

        render json: { data: serialize(setting) }
      end

      private

      def serialize(setting)
        { enabled: setting.enabled?, interval_minutes: setting.interval_minutes }
      end
    end
  end
end
