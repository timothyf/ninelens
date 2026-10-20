module Api
  module Admin
    class TasksController < ApplicationController
      before_action :require_authenticated_user
      before_action :require_admin_user

      def index
        render json: {
          data: AdminTaskRunner.catalog,
          meta: {
            deployment: deployment_metadata,
            schedule_import_range: schedule_import_range,
            schedule_date_range: schedule_date_range,
            roster_coverage: roster_coverage,
            mlb_teams: mlb_teams,
            database: database_metrics,
            player_season_stats: player_season_stats_metrics,
            pitch_data: pitch_data_metrics,
            game_details: game_details_metrics,
            daily_analytics: daily_analytics_metrics,
            contextual_benchmarks: contextual_benchmark_metrics
          }
        }
      end

      def run
        AuditLog.record!(user: current_user, action: "import_started", record: current_user,
          metadata: { "task_name" => params[:task_name].to_s, "parameters" => params.to_unsafe_h.except("controller", "action") })
        run = launch_task
        render json: { data: AdminTaskRunSerializer.call(run) }, status: :accepted
      rescue ArgumentError => error
        render json: { message: error.message, errors: [ error.message ] }, status: :unprocessable_content
      rescue StandardError => error
        if enqueue_error?(error)
          render json: { message: error.message, errors: [ error.message ] }, status: :service_unavailable
        else
          raise
        end
      end

      private

      def deployment_metadata
        commit = ENV["GIT_COMMIT"].to_s
        {
          version: ENV["DEPLOY_VERSION"].presence || "development",
          commit: commit,
          short_commit: commit.first(7).presence
        }
      end

      def task_params
        params.permit(
          :start_date,
          :end_date,
          :game_types,
          :chunk_days,
          :replace_existing,
          :sport_id,
          :only_missing,
          :batch_size,
          :limit,
          :mlb_ids,
          :team_scope,
          :team_mlb_id,
          :season,
          :snapshot_on,
          :mlb_game_id,
          :calculation_version
        )
      end

      def launch_task
        case params[:task_name]
        when MlbGameDetailsTaskLauncher::TASK_NAME
          MlbGameDetailsTaskLauncher.call(
            start_date: task_params[:start_date],
            end_date: task_params[:end_date],
            mlb_game_id: task_params[:mlb_game_id],
            initiated_by: current_user
          )
        when PitchDataSyncTaskLauncher::TASK_NAME
          PitchDataSyncTaskLauncher.call(
            start_date: task_params[:start_date],
            end_date: task_params[:end_date],
            game_types: task_params[:game_types],
            chunk_days: task_params[:chunk_days],
            replace_existing: task_params[:replace_existing],
            initiated_by: current_user
          )
        when MlbRosterSyncTaskLauncher::TASK_NAME
          MlbRosterSyncTaskLauncher.call(
            team_scope: task_params[:team_scope],
            team_mlb_id: task_params[:team_mlb_id],
            season: task_params[:season],
            initiated_by: current_user
          )
        else
          AdminTaskLauncher.call(task_name: params[:task_name], params: task_params.to_h, initiated_by: current_user)
        end
      end

      def enqueue_error?(error)
        error.is_a?(SolidQueue::Job::EnqueueError) ||
          error.class.name == "ActiveJob::EnqueueError" ||
          error.class.name.end_with?("::EnqueueFailure")
      end

      def schedule_date_range
        games = Game.arel_table
        earliest_date, latest_date = Game.pick(games[:official_date].minimum, games[:official_date].maximum)

        {
          earliest_game_date: earliest_date&.iso8601,
          latest_game_date: latest_date&.iso8601
        }
      end

      def schedule_import_range
        schedules = Schedule.arel_table
        earliest_date, latest_date = Schedule.pick(schedules[:start_date].minimum, schedules[:end_date].maximum)

        {
          earliest_import_date: earliest_date&.iso8601,
          latest_import_date: latest_date&.iso8601
        }
      end

      def roster_coverage
        memberships = TeamMembership.arel_table
        earliest_date, latest_start_date, latest_end_date = TeamMembership.pick(
          memberships[:starts_on].minimum,
          memberships[:starts_on].maximum,
          memberships[:ends_on].maximum
        )
        latest_date_candidates = [latest_start_date, latest_end_date]
        latest_date_candidates << Date.current if TeamMembership.where(ends_on: nil).exists?

        {
          earliest_date: earliest_date&.iso8601,
          latest_date: latest_date_candidates.compact.max&.iso8601
        }
      end

      def mlb_teams
        Team.where(mlb_id: MlbRosterBatchSync::ALL_TEAM_IDS).order(:name).map do |team|
          {
            id: team.id,
            mlb_id: team.mlb_id,
            name: team.name,
            abbreviation: team.abbreviation,
            league: MlbRosterBatchSync.league_for(team.mlb_id)
          }
        end
      end

      def database_metrics
        connection = ActiveRecord::Base.connection
        size_bytes = database_size_bytes(connection)
        tables = database_table_metrics(connection)

        {
          environment: Rails.env,
          adapter: connection.adapter_name,
          database_name: database_name(connection),
          server_version: database_server_version(connection),
          size_bytes: size_bytes,
          user_table_size_bytes: tables.sum { |table| table[:total_size_bytes] },
          table_count: tables.length,
          estimated_row_count: tables.sum { |table| table[:estimated_row_count] },
          estimated_dead_row_count: tables.sum { |table| table[:estimated_dead_row_count] },
          statistics_collected_since: database_statistics_reset_at(connection),
          largest_tables: tables.first(10).map do |table|
            table.merge(database_percentage: percentage(table[:total_size_bytes], size_bytes))
          end,
          most_read_tables: tables.sort_by do |table|
            [-table[:total_scans], -table[:rows_read_or_fetched], table[:table_name]]
          end.first(10).map do |table|
            table.slice(
              :table_name,
              :total_scans,
              :sequential_scans,
              :index_scans,
              :rows_read_or_fetched,
              :last_sequential_scan_at,
              :last_index_scan_at
            )
          end,
          measured_at: Time.current
        }
      end

      def database_size_bytes(connection)
        return unless connection.adapter_name.downcase.include?("postgres")

        connection.select_value("SELECT pg_database_size(current_database())").to_i
      end

      def database_name(connection)
        return connection.pool.db_config.database unless postgres?(connection)

        connection.select_value("SELECT current_database()")
      end

      def database_server_version(connection)
        return unless postgres?(connection)

        connection.select_value("SHOW server_version")
      end

      def database_statistics_reset_at(connection)
        return unless postgres?(connection)

        connection.select_value(<<~SQL.squish)
          SELECT COALESCE(stats_reset, pg_postmaster_start_time())
          FROM pg_stat_database
          WHERE datname = current_database()
        SQL
      end

      def database_table_metrics(connection)
        return [] unless postgres?(connection)

        last_scan_columns = if connection.select_value("SHOW server_version_num").to_i >= 160_000
          "s.last_seq_scan, s.last_idx_scan"
        else
          "NULL::timestamptz AS last_seq_scan, NULL::timestamptz AS last_idx_scan"
        end

        sql = <<~SQL.squish
          SELECT
            c.relname AS table_name,
            pg_total_relation_size(c.oid)::bigint AS total_size_bytes,
            pg_relation_size(c.oid)::bigint AS data_size_bytes,
            pg_indexes_size(c.oid)::bigint AS index_size_bytes,
            GREATEST(COALESCE(s.n_live_tup, c.reltuples)::bigint, 0) AS estimated_row_count,
            GREATEST(COALESCE(s.n_dead_tup, 0)::bigint, 0) AS estimated_dead_row_count,
            COALESCE(s.seq_scan, 0)::bigint AS sequential_scans,
            COALESCE(s.idx_scan, 0)::bigint AS index_scans,
            (COALESCE(s.seq_scan, 0) + COALESCE(s.idx_scan, 0))::bigint AS total_scans,
            (COALESCE(s.seq_tup_read, 0) + COALESCE(s.idx_tup_fetch, 0))::bigint AS rows_read_or_fetched,
            #{last_scan_columns}
          FROM pg_class c
          INNER JOIN pg_namespace n ON n.oid = c.relnamespace
          LEFT JOIN pg_stat_user_tables s ON s.relid = c.oid
          WHERE c.relkind IN ('r', 'p')
            AND n.nspname = current_schema()
            AND c.relname NOT IN ('schema_migrations', 'ar_internal_metadata')
          ORDER BY total_size_bytes DESC, table_name ASC
        SQL

        connection.select_all(sql).map do |row|
          {
            table_name: row.fetch("table_name"),
            total_size_bytes: row.fetch("total_size_bytes").to_i,
            data_size_bytes: row.fetch("data_size_bytes").to_i,
            index_size_bytes: row.fetch("index_size_bytes").to_i,
            estimated_row_count: row.fetch("estimated_row_count").to_i,
            estimated_dead_row_count: row.fetch("estimated_dead_row_count").to_i,
            sequential_scans: row.fetch("sequential_scans").to_i,
            index_scans: row.fetch("index_scans").to_i,
            total_scans: row.fetch("total_scans").to_i,
            rows_read_or_fetched: row.fetch("rows_read_or_fetched").to_i,
            last_sequential_scan_at: row.fetch("last_seq_scan"),
            last_index_scan_at: row.fetch("last_idx_scan")
          }
        end
      end

      def percentage(value, total)
        return 0.0 if total.to_i.zero?

        ((value.to_f / total) * 100).round(2)
      end

      def postgres?(connection)
        connection.adapter_name.downcase.include?("postgres")
      end

      def player_season_stats_metrics
        stats = PlayerSeasonStat.arel_table
        earliest_season, latest_season = PlayerSeasonStat.pick(stats[:season].minimum, stats[:season].maximum)

        {
          earliest_season: earliest_season,
          latest_season: latest_season,
          approximate_row_count: approximate_row_count(PlayerSeasonStat)
        }
      end

      def pitch_data_metrics
        pitches = PitchDatum.arel_table
        earliest_date, latest_date = PitchDatum.pick(pitches[:game_date].minimum, pitches[:game_date].maximum)

        {
          earliest_game_date: earliest_date&.iso8601,
          latest_game_date: latest_date&.iso8601,
          approximate_row_count: approximate_row_count(PitchDatum)
        }
      end

      def game_details_metrics
        synchronized = Game.where.not(details_last_synced_at: nil)
        dates = Game.arel_table
        earliest_date, latest_date = synchronized.pick(dates[:official_date].minimum, dates[:official_date].maximum)

        {
          synchronized_game_count: synchronized.count,
          earliest_game_date: earliest_date&.iso8601,
          latest_game_date: latest_date&.iso8601,
          batting_line_count: GamePlayerBattingLine.count,
          pitching_line_count: GamePlayerPitchingLine.count,
          plate_appearance_count: PlateAppearance.count,
          linked_pitch_count: PitchDatum.where.not(plate_appearance_id: nil).count
        }
      end

      def daily_analytics_metrics
        models = DailyAnalyticsRefresh::SUMMARY_MODELS
        ranges = models.flat_map do |model|
          table = model.arel_table
          model.pick(table[:metric_date].minimum, table[:metric_date].maximum)
        end.compact

        {
          calculation_version: DailyAnalyticsRefresh::CALCULATION_VERSION,
          earliest_metric_date: ranges.min&.iso8601,
          latest_metric_date: ranges.max&.iso8601,
          row_counts: models.to_h { |model| [ model.table_name, approximate_row_count(model) ] },
          last_calculated_at: models.filter_map { |model| model.maximum(:calculated_at) }.max
        }
      end

      def contextual_benchmark_metrics
        benchmarks = LeagueMetricBenchmark.for_version(DailyAnalyticsRefresh::CALCULATION_VERSION)
        {
          calculation_version: DailyAnalyticsRefresh::CALCULATION_VERSION,
          benchmark_count: approximate_row_count(LeagueMetricBenchmark),
          percentile_count: approximate_row_count(PlayerMetricPercentile),
          earliest_source_date: benchmarks.minimum(:source_start_date)&.iso8601,
          latest_source_date: benchmarks.maximum(:source_end_date)&.iso8601,
          last_calculated_at: benchmarks.maximum(:calculated_at)
        }
      end

      def approximate_row_count(model)
        connection = ActiveRecord::Base.connection
        return model.count unless connection.adapter_name.downcase.include?("postgres")

        table_name = connection.quote(model.table_name)
        estimate = connection.select_value("SELECT reltuples::bigint FROM pg_class WHERE oid = #{table_name}::regclass").to_i
        [ estimate, 0 ].max
      end
    end
  end
end
