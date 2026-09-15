module Api
  class PlayerSeasonStatsController < ApplicationController
    before_action :set_player_season_stat, only: [:show, :update, :destroy]
    before_action :require_authenticated_user, only: [:import, :download]
    before_action :require_admin_user, only: [:import, :download]

    def index
      if params[:view] == "leaderboard"
        query = PlayerSeasonStatsLeaderboardQuery.new(params: index_params)

        if ActiveModel::Type::Boolean.new.cast(params[:metadata_only])
          render json: { data: [], meta: query.metadata }
          return
        end

        render json: {
          data: query.results,
          meta: ActiveModel::Type::Boolean.new.cast(params[:defer_facets]) ? query.base_metadata : query.metadata
        }
        return
      end

      query = PlayerSeasonStatsIndexQuery.new(params: index_params)

      render json: {
        data: query.results.map { |player_season_stat| serialize_player_season_stat(player_season_stat) },
        meta: query.metadata
      }
    end

    def show
      render json: { data: serialize_player_season_stat(@player_season_stat) }
    end

    def create
      player_season_stat = PlayerSeasonStat.new(player_season_stat_params)

      if player_season_stat.save
        render json: { data: serialize_player_season_stat(player_season_stat) }, status: :created
      else
        render json: { errors: player_season_stat.errors.full_messages }, status: :unprocessable_content
      end
    end

    def import
      record_import_started("player_season_stats_import")
      uploaded_file = import_params[:file]

      if uploaded_file.blank?
        render json: { errors: ["CSV file is required"] }, status: :unprocessable_content
        return
      end

      run = AdminImportTaskLauncher.call(
        task_name: "player_season_stats_import",
        uploaded_file:,
        initiated_by: current_user,
        params: {
          required_stat_columns: import_params[:required_stat_columns],
          replace_season: import_params[:replace_season]
        }
      )
      render_task_run(run)
    rescue ArgumentError => error
      render json: { message: error.message, errors: [ error.message ] }, status: :unprocessable_content
    rescue AdminImportTaskLauncher::EnqueueFailure, SolidQueue::Job::EnqueueError => error
      render json: { message: error.message, errors: [ error.message ] }, status: :service_unavailable
    end

    def download
      record_import_started("player_season_stats_download_import")
      run = AdminImportTaskLauncher.call(
        task_name: "player_season_stats_download",
        initiated_by: current_user,
        params: download_params.to_h
      )
      render_task_run(run)
    rescue ArgumentError => error
      render json: { message: error.message, errors: [ error.message ] }, status: :unprocessable_content
    rescue AdminImportTaskLauncher::EnqueueFailure, SolidQueue::Job::EnqueueError => error
      render json: { message: error.message, errors: [ error.message ] }, status: :service_unavailable
    end

    def update
      if @player_season_stat.update(player_season_stat_params)
        render json: { data: serialize_player_season_stat(@player_season_stat) }
      else
        render json: { errors: @player_season_stat.errors.full_messages }, status: :unprocessable_content
      end
    end

    def destroy
      @player_season_stat.destroy
      head :no_content
    end

    private

    def set_player_season_stat
      @player_season_stat = PlayerSeasonStat.find(params[:id])
    end

    def index_params
      params.permit(
        :view,
        :page,
        :per_page,
        :sort,
        :defer_facets,
        :metadata_only,
        filter: [:season, :season_start, :season_end, :team_id, :position_id, :league, :scope_type, :scope_key, :player_id, :team_name, :player_name, :stat_type_name, :category, :min_value, :max_value]
      ).to_h
    end

    def player_season_stat_params
      params.require(:player_season_stat).permit(:player_id, :team_id, :stat_type_id, :season, :scope_type, :scope_key, :value)
    end

    def import_params
      params.permit(:file, :replace_season, required_stat_columns: [])
    end

    def download_params
      params.permit(:category, :start_year, :end_year, :replace_season)
    end

    def record_import_started(task_name)
      return unless current_user

      AuditLog.record!(user: current_user, action: "import_started", record: current_user,
        metadata: { "task_name" => task_name, "source_name" => params[:file]&.original_filename })
    end

    def render_task_run(run)
      render json: { data: AdminTaskRunSerializer.call(run) }, status: :accepted
    end

    def serialize_player_season_stat(player_season_stat)
      {
        id: player_season_stat.id,
        player_id: player_season_stat.player_id,
        stat_type_id: player_season_stat.stat_type_id,
        season: player_season_stat.season,
        scope_type: player_season_stat.scope_type,
        scope_key: player_season_stat.scope_key,
        value: player_season_stat.value.to_s("F"),
        player: serialize_player(player_season_stat.player),
        team: serialize_team(player_season_stat),
        stat_type: serialize_stat_type(player_season_stat.stat_type),
        created_at: player_season_stat.created_at,
        updated_at: player_season_stat.updated_at
      }
    end

    def serialize_player(player)
      {
        id: player.id,
        mlb_id: player.mlb_id,
        first_name: player.first_name,
        last_name: player.last_name,
        full_name: "#{player.first_name} #{player.last_name}"
      }
    end

    def serialize_team(player_season_stat)
      team = player_season_stat.team || player_season_stat.player.team

      if player_season_stat.scope_type != "team"
        return {
          id: nil,
          mlb_id: nil,
          name: player_season_stat.scope_key,
          abbreviation: player_season_stat.scope_key,
          team_name: player_season_stat.scope_key,
          location_name: nil,
          short_name: player_season_stat.scope_key
        }
      end

      {
        id: team.id,
        mlb_id: team.mlb_id,
        name: team.name,
        abbreviation: team.abbreviation,
        team_name: team.team_name,
        location_name: team.location_name,
        short_name: team.short_name
      }
    end

    def serialize_stat_type(stat_type)
      {
        id: stat_type.id,
        name: stat_type.name,
        label: stat_type.label,
        category: stat_type.category
      }
    end
  end
end
