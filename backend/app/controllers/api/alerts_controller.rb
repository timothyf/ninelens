module Api
  class AlertsController < ApplicationController
    before_action :require_authenticated_user
    before_action :load_alert, only: [ :show, :acknowledge, :snooze, :assign, :resolve ]

    def index
      AlertInboxSync.call(user: current_user)
      current_user.alerts.where(status: "snoozed").find_each(&:reopen_if_snooze_expired!)
      alerts = current_user.alerts.includes(:assigned_to, player_trend_event: :player).recent_first
      alerts = alerts.where(status: params[:status]) if params[:status].present? && Alert::STATUSES.include?(params[:status])
      if params[:severity].present? && PlayerTrendEvent::SEVERITIES.include?(params[:severity])
        alerts = alerts.joins(:player_trend_event).where(player_trend_events: { severity: params[:severity] })
      end
      alerts = alerts.joins(:player_trend_event).where(player_trend_events: { player_id: params[:player_id] }) if params[:player_id].present?
      render json: { data: alerts.limit([ params.fetch(:limit, 50).to_i, 100].min).map { |alert| serialize(alert) }, meta: { unread_count: current_user.alerts.where(status: "active").count } }
    end

    def show
      render json: { data: serialize(@alert) }
    end

    def acknowledge
      @alert.acknowledge!
      audit("acknowledged")
      render json: { data: serialize(@alert) }
    end

    def snooze
      until_at = Time.zone.parse(params.require(:until))
      raise ArgumentError, "until must be a future timestamp" unless until_at && until_at > Time.current
      @alert.snooze!(until_at: until_at)
      audit("snoozed")
      render json: { data: serialize(@alert) }
    rescue ActionController::ParameterMissing, ArgumentError => error
      render json: { message: error.message }, status: :unprocessable_content
    end

    def assign
      assignee = User.active.find(params.require(:user_id))
      @alert.update!(assigned_to: assignee)
      audit("assigned", { assigned_to_id: assignee.id })
      render json: { data: serialize(@alert) }
    rescue ActiveRecord::RecordNotFound
      render json: { message: "Assignee was not found" }, status: :not_found
    end

    def resolve
      @alert.resolve!
      audit("resolved")
      render json: { data: serialize(@alert) }
    end

    private

    def load_alert
      @alert = current_user.alerts.includes(:assigned_to, player_trend_event: :player).find(params[:id])
    end

    def audit(action, changes = {})
      AuditLog.record!(user: current_user, action: action, record: @alert, changes: changes.presence || @alert.saved_changes)
    end

    def serialize(alert)
      event = alert.player_trend_event
      player = event.player
      {
        id: alert.id,
        status: alert.status,
        severity: event.severity,
        title: "#{event.event_type.to_s.humanize} for #{player.full_name}",
        event_type: event.event_type,
        role: event.role,
        metric_key: event.metric_key,
        direction: event.direction,
        detected_at: event.detected_at,
        onset_date: event.onset_date,
        acknowledged_at: alert.acknowledged_at,
        snoozed_until: alert.snoozed_until,
        resolved_at: alert.resolved_at,
        assigned_to: alert.assigned_to && { id: alert.assigned_to.id, name: alert.assigned_to.name, email: alert.assigned_to.email },
        player: { id: player.id, mlb_id: player.mlb_id, full_name: player.full_name },
        evidence: alert.supporting_evidence,
        links: alert.links,
        subscription_id: alert.alert_subscription_id
      }
    end
  end
end
