module Api
  class SeasonAwardsController < ApplicationController
    def show
      season = Integer(params[:season], exception: false)
      unless season && season > 1800 && season <= ApplicationCalendar.current_date.year && Schedule.exists?(season: season)
        return render json: { message: "Season must be an available year" }, status: :unprocessable_content
      end

      sync = MlbSeasonAwardsSync.call(season: season)
      awards = SeasonAward.where(season: season).order(:award_id, :player_name).to_a
      player_ids = Player.where(mlb_id: awards.map(&:player_mlb_id)).pluck(:mlb_id, :id).to_h
      teams_by_mlb_id = Team.where(mlb_id: awards.filter_map(&:team_mlb_id))
        .select(:id, :mlb_id, :abbreviation).index_by(&:mlb_id)

      groups = SeasonAward::AWARD_GROUPS.map do |name, leagues|
        {
          name: name,
          leagues: leagues.map do |league, award_id|
            {
              name: league,
              recipients: awards.select { |award| award.award_id == award_id }.map do |award|
                {
                  player_id: player_ids[award.player_mlb_id],
                  player_name: award.player_name,
                  team_id: teams_by_mlb_id[award.team_mlb_id]&.id,
                  team_abbreviation: teams_by_mlb_id[award.team_mlb_id]&.abbreviation,
                  position: award.position,
                  awarded_on: award.awarded_on
                }
              end
            }
          end
        }
      end

      render json: { data: {
        season: season,
        groups: groups,
        status: sync[:success] ? (awards.any? ? "ready" : (season == ApplicationCalendar.current_date.year ? "pending" : "empty")) : (awards.any? ? "stale" : "unavailable"),
        last_synced_at: SeasonAwardSync.find_by(season: season)&.last_synced_at
      } }
    end
  end
end
