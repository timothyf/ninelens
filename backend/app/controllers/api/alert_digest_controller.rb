module Api
  class AlertDigestController < ApplicationController
    before_action :require_authenticated_user

    def show
      AlertInboxSync.call(user: current_user)
      default_window = current_user.alert_digest_frequency == "weekly" ? 7.days : 24.hours
      since = params[:since].present? ? Time.zone.parse(params[:since]) : default_window.ago
      alerts = current_user.alerts.includes(player_trend_event: :player).where("alerts.created_at >= ?", since).recent_first
      render json: { data: { frequency: current_user.alert_digest_frequency, day: current_user.alert_digest_day, hour: current_user.alert_digest_hour, since: since, alerts: alerts.map { |alert| digest_alert(alert) } } }
    end

    def update
      current_user.update!(digest_params)
      render json: { data: { frequency: current_user.alert_digest_frequency, day: current_user.alert_digest_day, hour: current_user.alert_digest_hour } }
    rescue ActiveRecord::RecordInvalid => error
      render json: { message: error.record.errors.full_messages.to_sentence }, status: :unprocessable_content
    end

    private

    def digest_params
      params.permit(:alert_digest_frequency, :alert_digest_day, :alert_digest_hour)
    end

    def digest_alert(alert)
      event = alert.player_trend_event
      { id: alert.id, severity: event.severity, player: event.player.full_name, event_type: event.event_type, status: alert.status, links: alert.links }
    end
  end
end
