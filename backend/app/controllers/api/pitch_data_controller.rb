module Api
  class PitchDataController < ApplicationController
    wrap_parameters false
    before_action :require_authenticated_user, only: :import
    before_action :require_admin_user, only: :import

    DEFAULT_PER_PAGE = 20
    MAX_PER_PAGE = 500

    def index
      rows = PitchDatum.order(game_date: :desc, game_pk: :desc, inning: :asc, at_bat_number: :asc, pitch_number: :asc)
      rows = apply_filters(rows)
      total_count = rows.count
      rows = rows.offset((page_param - 1) * per_page_param).limit(per_page_param)

      player_ids = rows.flat_map { |r| [r.pitcher, r.batter] }.compact.uniq
      player_names = Player.where(mlb_id: player_ids).pluck(:mlb_id, :first_name, :last_name)
                           .each_with_object({}) { |(id, fn, ln), h| h[id] = "#{fn} #{ln}" }

      render json: {
        data: rows.map { |row| serialize_pitch_datum(row, player_names) },
        meta: {
          count: rows.length,
          limit: per_page_param,
          page: page_param,
          per_page: per_page_param,
          total_pages: total_pages(total_count, per_page_param),
          total_count: total_count,
          available_events: available_events,
          available_pitch_types: available_pitch_types,
          data_range: data_range,
          filters: active_filters
        }
      }
    end

    def import
      record_import_started("pitch_data_import")
      uploaded_file = import_params[:file]

      if uploaded_file.blank?
        render json: { errors: ["CSV file is required"] }, status: :unprocessable_content
        return
      end

      run = AdminImportTaskLauncher.call(
        task_name: "pitch_data_import",
        uploaded_file:,
        initiated_by: current_user
      )
      render_task_run(run)
    rescue ArgumentError => error
      render json: { message: error.message, errors: [ error.message ] }, status: :unprocessable_content
    rescue AdminImportTaskLauncher::EnqueueFailure, SolidQueue::Job::EnqueueError => error
      render json: { message: error.message, errors: [ error.message ] }, status: :service_unavailable
    end

    private

    def import_params
      @import_params ||= params.permit(:file)
    end

    def record_import_started(task_name)
      return unless current_user

      AuditLog.record!(user: current_user, action: "import_started", record: current_user,
        metadata: { "task_name" => task_name, "source_name" => params[:file]&.original_filename })
    end

    def render_task_run(run)
      render json: { data: AdminTaskRunSerializer.call(run) }, status: :accepted
    end

    def page_param
      raw = Integer(params[:page], exception: false)
      return 1 if raw.nil?

      raw.clamp(1, 1_000_000)
    end

    def per_page_param
      raw = Integer(params[:per_page] || params[:limit], exception: false)
      return DEFAULT_PER_PAGE if raw.nil?

      raw.clamp(1, MAX_PER_PAGE)
    end

    def total_pages(total_count, per_page)
      return 1 if total_count.zero?

      (total_count.to_f / per_page).ceil
    end

    def apply_filters(rows)
      filtered_rows = rows

      if active_filters[:game_date].present?
        parsed_date = Date.iso8601(active_filters[:game_date]) rescue nil
        filtered_rows = filtered_rows.where(game_date: parsed_date) if parsed_date
      else
        start_date = parse_iso_date(active_filters[:game_date_start])
        end_date = parse_iso_date(active_filters[:game_date_end])

        if start_date && end_date && start_date > end_date
          start_date, end_date = end_date, start_date
        end

        filtered_rows = filtered_rows.where("game_date >= ?", start_date) if start_date
        filtered_rows = filtered_rows.where("game_date <= ?", end_date) if end_date
      end

      if active_filters[:game_pk].present?
        game_pk = Integer(active_filters[:game_pk], exception: false)
        filtered_rows = filtered_rows.where(game_pk: game_pk) if game_pk
      end

      if active_filters[:pitcher].present?
        pitcher = Integer(active_filters[:pitcher], exception: false)
        filtered_rows = filtered_rows.where(pitcher: pitcher) if pitcher
      end

      if active_filters[:batter].present?
        batter = Integer(active_filters[:batter], exception: false)
        filtered_rows = filtered_rows.where(batter: batter) if batter
      end

      if active_filters[:pitch_type].present?
        filtered_rows = filtered_rows.where("LOWER(pitch_type) = ?", active_filters[:pitch_type].downcase)
      end

      if active_filters[:events].present?
        filtered_rows = filtered_rows.where("LOWER(events) = ?", active_filters[:events].downcase)
      end

      filtered_rows
    end

    def active_filters
      @active_filters ||= params.permit(:game_date, :game_date_start, :game_date_end, :game_pk, :pitcher, :batter, :pitch_type, :events).to_h.symbolize_keys
    end

    def available_events
      @available_events ||= PitchDatum.where.not(events: [nil, ""]).distinct.order(:events).pluck(:events)
    end

    def available_pitch_types
      @available_pitch_types ||= PitchDatum.where.not(pitch_type: [nil, ""]).distinct.order(:pitch_type).pluck(:pitch_type)
    end

    def data_range
      @data_range ||= {
        type: "game_date",
        start: PitchDatum.minimum(:game_date)&.iso8601,
        end: PitchDatum.maximum(:game_date)&.iso8601
      }
    end

    def parse_iso_date(value)
      return nil if value.blank?

      Date.iso8601(value)
    rescue ArgumentError
      nil
    end

    def serialize_pitch_datum(row, player_names = {})
      {
        id: row.id,
        game_id: row.game_id,
        game_date: row.game_date,
        game_pk: row.game_pk,
        at_bat_number: row.at_bat_number,
        pitch_number: row.pitch_number,
        pitcher: row.pitcher,
        pitcher_name: player_names[row.pitcher],
        player_name: row.player_name,
        batter: row.batter,
        batter_name: player_names[row.batter],
        pitch_type: row.pitch_type,
        release_speed: row.release_speed,
        release_spin_rate: row.release_spin_rate,
        launch_speed: row.launch_speed,
        launch_angle: row.launch_angle,
        hit_distance_sc: row.hit_distance_sc,
        balls: row.balls,
        strikes: row.strikes,
        zone: row.zone,
        inning: row.inning,
        inning_topbot: row.inning_topbot,
        description: row.description,
        events: row.events,
        pitch_name: row.pitch_name,
        raw_data: row.raw_data,
        created_at: row.created_at,
        updated_at: row.updated_at
      }
    end
  end
end
