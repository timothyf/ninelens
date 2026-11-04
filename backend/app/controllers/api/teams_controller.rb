module Api
  class TeamsController < ApplicationController
    def index
      teams = Team.where(mlb_id: MlbRosterBatchSync::ALL_TEAM_IDS).order(:name)
      filter = params[:filter] || {}
      name_filter = filter[:name] || filter["name"]
      if name_filter.present?
        query = ActiveRecord::Base.sanitize_sql_like(name_filter.to_s.strip)
        pattern = "%#{query}%"
        teams = teams.where(
          "teams.name ILIKE :pattern OR teams.team_name ILIKE :pattern OR teams.location_name ILIKE :pattern OR teams.short_name ILIKE :pattern OR teams.abbreviation ILIKE :pattern",
          pattern: pattern
        )
      end
      teams = teams.limit([[params[:per_page].to_i, 1].max, 50].min) if params[:per_page].present?

      render json: {
        data: teams.map { |team| serialize_team(team) },
        meta: { total_count: teams.size }
      }
    end

    def show
      team = Team.find(params[:id])
      includes = params[:include].presence&.split(",") || [ "all" ]
      snapshot = TeamProfileSnapshotQuery.new(team: team, season: params[:season], user: current_user, includes: includes).result

      render json: { data: serialize_team(team).merge(snapshot) }
    rescue ActiveRecord::RecordNotFound
      render_team_not_found
    rescue StandardError => error
      render_team_failure(error, context: "Team profile", message: "Unable to load team profile")
    end

    def stats_summary
      team = Team.find(params[:id])
      summary = TeamProfileSnapshotQuery.new(team: team, season: params[:season]).official_stats_summary
      render json: { data: summary }
    rescue ActiveRecord::RecordNotFound
      render_team_not_found
    rescue StandardError => error
      render_team_failure(error, context: "Team stats summary", message: "Unable to load team stats summary")
    end

    private

    def render_team_not_found
      render json: { message: "Team not found", request_id: request.request_id }, status: :not_found
    end

    def render_team_failure(error, context:, message:)
      Rails.logger.error("[#{request.request_id}] #{context} failed: #{error.class}: #{error.message}")
      render json: { message: message, request_id: request.request_id }, status: :internal_server_error
    end

    def serialize_team(team)
      {
        id: team.id,
        mlb_id: team.mlb_id,
        name: team.name,
        abbreviation: team.abbreviation,
        team_name: team.team_name,
        location_name: team.location_name,
        short_name: team.short_name,
        team_code: team.team_code,
        file_code: team.file_code,
        logo_url: team.logo_url,
        created_at: team.created_at,
        updated_at: team.updated_at
      }
    end
  end
end
