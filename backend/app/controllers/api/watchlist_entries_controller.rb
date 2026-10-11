module Api
  class WatchlistEntriesController < ApplicationController
    before_action :require_authenticated_user

    def create
      watchlist = accessible_watchlists.find(params[:watchlist_id])
      require_write_access!(watchlist)
      return if performed?
      attributes = entry_params.to_h
      attributes["candidate_owner_id"] ||= current_user.id
      entry = watchlist.entries.create!(attributes)
      AuditLog.record!(user: current_user, action: "created", record: entry, changes: entry.saved_changes)
      render json: { data: WatchlistEntrySerializer.call(entry) }, status: :created
    rescue ActiveRecord::RecordInvalid => error
      render json: { message: error.record.errors.full_messages.to_sentence }, status: :unprocessable_content
    end

    def update
      entry = accessible_entries.includes(player: [ :team, :profile ]).find(params[:id])
      require_write_access!(entry.watchlist)
      return if performed?
      entry.update!(entry_params)
      AuditLog.record!(user: current_user, action: "updated", record: entry, changes: entry.saved_changes)
      render json: { data: WatchlistEntrySerializer.call(entry) }
    rescue ActiveRecord::RecordInvalid => error
      render json: { message: error.record.errors.full_messages.to_sentence }, status: :unprocessable_content
    end

    def transition
      entry = accessible_entries.includes(player: [ :team, :profile ]).find(params[:id])
      require_write_access!(entry.watchlist)
      return if performed?

      before = entry.review_status
      entry.update!(review_status: params.require(:review_status))
      AuditLog.record!(user: current_user, action: "review_status_changed", record: entry,
        changes: { "review_status" => [ before, entry.review_status ] })
      render json: { data: WatchlistEntrySerializer.call(entry) }
    rescue ActionController::ParameterMissing, ActiveRecord::RecordInvalid => error
      message = error.respond_to?(:record) ? error.record.errors.full_messages.to_sentence : error.message
      render json: { message: message }, status: :unprocessable_content
    end

    def audit_history
      entry = accessible_entries.find(params[:id])
      render json: { data: AuditHistoryQuery.call(auditable: entry) }
    end

    def destroy
      entry = accessible_entries.find(params[:id])
      require_write_access!(entry.watchlist)
      return if performed?
      AuditLog.record!(user: current_user, action: "deleted", record: entry, changes: entry.attributes)
      entry.destroy!
      head :no_content
    end

    def recalculate
      entry = accessible_entries.includes(:watchlist, player: [ :team, :profile ]).find(params[:id])
      require_write_access!(entry.watchlist)
      return if performed?
      return render json: { message: "Attach a need profile before calculating fit." },
        status: :unprocessable_content unless entry.watchlist.need_profile

      entry.recalculate_fit!
      AuditLog.record!(user: current_user, action: "recalculated", record: entry, changes: entry.saved_changes)
      render json: { data: WatchlistEntrySerializer.call(entry.reload) }
    end

    def alternatives
      entry = accessible_entries.includes(watchlist: :need_profile, player: [ :team, :profile, { player_positions: :position } ]).find(params[:id])
      render json: {
        data: NeedProfileAlternativesQuery.new(entry: entry, limit: params[:limit] || 5).result,
        meta: { need_profile_id: entry.watchlist.need_profile_id, source_player_id: entry.player_id }
      }
    end

    private

    def entry_params
      params.permit(
        :player_id, :candidate_owner_id, :priority, :status, :review_status, :recommendation,
        :fit_score, :need_score, :cost_score, :risk_score, :acquisition_rationale,
        :estimated_cost, :availability, :concerns, :notes, tags: []
      )
    end

    def accessible_watchlists
      current_user.admin? ? Watchlist.all : Watchlist.where(owner_id: current_user.id)
    end

    def accessible_entries
      current_user.admin? ? WatchlistEntry.all : WatchlistEntry.joins(:watchlist).where(watchlists: { owner_id: current_user.id })
    end
  end
end
