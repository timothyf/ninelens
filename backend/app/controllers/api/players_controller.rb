module Api
  class PlayersController < ApplicationController
    def index
      query = PlayersIndexQuery.new(params: index_params)

      render json: {
        data: query.results.map { |player| serialize_player(player) },
        meta: query.metadata
      }
    end

    def show
      player = Player.includes(:profile, :team, player_positions: :position).find(params[:id])
      analysis_range = PlayerAnalysisRange.resolve(player: player, params: analysis_params)
      snapshot = PlayerProfileSnapshotQuery.new(
        player: player,
        analysis_range: analysis_range,
        similarity_options: similarity_params
      ).result(
        sections: profile_sections
      )

      render json: {
        data: serialize_player(player, include_profile: true, include_positions: true, include_contract: true).merge(snapshot)
      }
    rescue ArgumentError => error
      render json: { message: error.message, errors: [ error.message ] }, status: :unprocessable_content
    end

    private

    def index_params
      params.permit(:page, :per_page, :sort, filter: [ :name, :first_name, :last_name, :team_id, :team_name ]).to_h
    end

    def analysis_params
      params.permit(:range, :start_date, :end_date, :pa_window, :pitch_window).to_h
    end

    def similarity_params
      params.permit(:similar_mode, :similar_season, :similar_min_age, :similar_max_age, :similar_position).to_h
    end

    def profile_sections
      return nil unless params.key?(:sections)

      params[:sections].to_s.split(",").map(&:strip).reject(&:blank?)
    end

    def serialize_player(player, include_profile: false, include_positions: false, include_contract: false)
      data = {
        id: player.id,
        mlb_id: player.mlb_id,
        first_name: player.first_name,
        last_name: player.last_name,
        full_name: player.full_name,
        team: serialize_team(player.team),
        display_team: serialize_team(player.display_team),
        created_at: player.created_at,
        updated_at: player.updated_at
      }

      if include_contract
        current_contract = player.current_contract
        data[:current_salary] = current_contract&.salary_amount
        data[:current_salary_season] = current_contract&.season
      end

      data[:profile] = serialize_profile(player.profile) if include_profile
      data[:positions] = serialize_player_positions(player.player_positions) if include_positions
      data
    end

    def serialize_profile(profile)
      return nil if profile.blank?

      {
        id: profile.id,
        birth_date: profile.birth_date,
        age: profile.age,
        height_inches: profile.height_inches,
        formatted_height: profile.formatted_height,
        weight_pounds: profile.weight_pounds,
        bats: profile.bats,
        throws: profile.throws,
        active: profile.raw_data.to_h["active"],
        last_played_date: profile.raw_data.to_h["lastPlayedDate"],
        draft_year: Integer(profile.raw_data.to_h["draftYear"], exception: false),
        draft_round: serialized_draft_round(profile),
        draft_round_pick_number: serialized_draft_value(profile, "roundPickNumber"),
        draft_pick_number: serialized_draft_value(profile, "pickNumber"),
        draft_team: serialized_draft_team(profile),
        awards: serialized_awards(profile),
        all_star_selections: serialized_all_star_selections(profile),
        mlb_debut_date: profile.mlb_debut_date,
        headshot_id: profile.headshot_id,
        headshot_url: profile.headshot_url,
        source_name: profile.source_name,
        source_updated_at: profile.source_updated_at,
        last_synced_at: profile.last_synced_at
      }
    end

    def serialized_awards(profile)
      profile_awards(profile).reject { |award| mlb_all_star_award?(award) }.map do |award|
        {
          id: award["id"],
          name: award["name"],
          season: Integer(award["season"], exception: false),
          date: award["date"]
        }
      end
    end

    def serialized_draft_team(profile)
      draft = serialized_draft(profile)
      team = draft&.fetch("team")
      return if team.blank?

      { id: Integer(team["id"], exception: false), name: team["name"] }
    end

    def serialized_draft_value(profile, keys)
      value = Array(keys).lazy.map { |key| serialized_draft(profile)&.[](key) }.find(&:present?)
      Integer(value, exception: false)
    end

    def serialized_draft_round(profile)
      value = Array(%w[round pickRound]).lazy.map { |key| serialized_draft(profile)&.[](key) }.find(&:present?)
      Integer(value, exception: false) || value
    end

    def serialized_draft(profile)
      Array(profile.raw_data.to_h["drafts"]).find { |entry| entry.is_a?(Hash) && entry.dig("team", "id").present? }
    end

    def serialized_all_star_selections(profile)
      profile_awards(profile).select { |award| mlb_all_star_award?(award) }.filter_map do |award|
        Integer(award["season"], exception: false)
      end.uniq.sort.reverse
    end

    def profile_awards(profile)
      Array(profile.raw_data.to_h["awards"]).select { |award| award.is_a?(Hash) && award["name"].present? }
    end

    def mlb_all_star_award?(award)
      %w[ALAS NLAS].include?(award["id"].to_s.upcase)
    end

    def serialize_player_positions(assignments)
      serialized_assignments = assignments
        .sort_by do |assignment|
          [
            assignment.season.nil? ? 0 : 1,
            -(assignment.season || 0),
            assignment.is_primary? ? 0 : 1,
            assignment.position.sort_order
          ]
        end
        .map do |assignment|
          {
            id: assignment.id,
            season: assignment.season,
            current: assignment.season.nil?,
            primary: assignment.is_primary,
            source_name: assignment.source_name,
            last_synced_at: assignment.last_synced_at,
            position: serialize_position(assignment.position)
          }
        end

      current_assignments = serialized_assignments.select { |assignment| assignment[:current] }
      primary_assignment = current_assignments.find { |assignment| assignment[:primary] }

      {
        primary: primary_assignment&.fetch(:position),
        secondary: current_assignments.reject { |assignment| assignment[:primary] }.map { |assignment| assignment[:position] },
        assignments: serialized_assignments
      }
    end

    def serialize_position(position)
      {
        id: position.id,
        mlb_code: position.mlb_code,
        abbreviation: position.abbreviation,
        name: position.name,
        position_type: position.position_type,
        sort_order: position.sort_order
      }
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
        file_code: team.file_code
      }
    end
  end
end
