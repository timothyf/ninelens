module Api
  class OpponentReportsController < ApplicationController
    before_action :require_authenticated_user

    def index
      reports = policy_scope(scoped_reports).includes(:team, :opponent_team).recent_first

      render json: { data: reports.map { |report| serialize_summary(report) } }
    end

    def show
      report = OpponentReport.includes(:team, :opponent_team).find(params[:id])
      return unless authorize!(report, :read?)

      render json: { data: serialize_report(report) }
    end

    def create
      return unless authorize_create!

      team = Team.find(params[:team_id])
      report = OpponentReportGenerator.call(
        team: team,
        season: report_params.fetch(:season, Date.current.year),
        owner: current_user
      )
      AuditLog.record!(user: current_user, action: "created", record: report, changes: report.saved_changes)

      render json: { data: serialize_report(report) }, status: :created
    rescue ArgumentError => error
      render json: { message: error.message, errors: [ error.message ] }, status: :unprocessable_content
    end

    def update
      report = OpponentReport.includes(:team, :opponent_team).find(params[:id])
      return unless authorize!(report, :update?)

      report.update!(update_params)
      AuditLog.record!(user: current_user, action: "updated", record: report, changes: report.saved_changes)
      render json: { data: serialize_report(report) }
    rescue ActiveRecord::RecordInvalid => error
      render json: { message: error.record.errors.full_messages.to_sentence }, status: :unprocessable_content
    end

    def refresh
      report = OpponentReport.find(params[:id])
      return unless authorize!(report, :update?)

      OpponentReportGenerator.new(
        team: report.team,
        season: report.season,
        on: Date.current,
        owner: report.owner
      ).refresh!(report)
      AuditLog.record!(user: current_user, action: "refreshed", record: report, changes: report.saved_changes)
      render json: { data: serialize_report(report) }
    rescue ArgumentError => error
      render json: { message: error.message, errors: [ error.message ] }, status: :unprocessable_content
    end

    def audit_history
      report = OpponentReport.find(params[:id])
      return unless authorize!(report, :read?)

      logs = AuditLog.includes(:user)
        .where(auditable_type: "OpponentReport", auditable_id: report.id)
        .order(created_at: :desc)
        .limit(100)
      render json: { data: logs.map { |log| AuditLogSerializer.call(log) } }
    end

    private

    def scoped_reports
      relation = OpponentReport.all
      relation = relation.where(team_id: params[:team_id]) if params[:team_id].present?
      relation
    end

    def report_params
      params.permit(:season)
    end

    def update_params
      params.permit(:title)
    end

    def policy_scope(relation)
      OwnedWorkflowPolicy::Scope.new(current_user, relation).resolve
    end

    def authorize_create!
      return true if OwnedWorkflowPolicy.new(current_user).create?

      render json: { message: "You are not authorized to create opponent reports" }, status: :forbidden
      false
    end

    def authorize!(report, action)
      return true if OwnedWorkflowPolicy.new(current_user, report).public_send(action)

      render json: { message: "You are not authorized to access this opponent report" }, status: :forbidden
      false
    end

    def serialize_summary(report)
      {
        id: report.id,
        owner: serialize_user(report.owner),
        title: report.title,
        season: report.season,
        series_starts_on: report.series_starts_on,
        series_ends_on: report.series_ends_on,
        generated_at: report.generated_at,
        team: serialize_team(report.team),
        opponent: serialize_team(report.opponent_team),
        probable_starter_count: Array(report.snapshot["probable_starters"]).length
      }
    end

    def serialize_report(report)
      serialize_summary(report).merge(snapshot: report.snapshot)
    end

    def serialize_team(team)
      { id: team.id, mlb_id: team.mlb_id, name: team.name, abbreviation: team.abbreviation }
    end

    def serialize_user(user)
      return nil unless user

      { id: user.id, name: user.name, email: user.email, role: user.role }
    end
  end
end
