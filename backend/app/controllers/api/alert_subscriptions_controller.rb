module Api
  class AlertSubscriptionsController < ApplicationController
    before_action :require_authenticated_user

    def index
      render json: { data: current_user.alert_subscriptions.includes(:player, :watchlist).map { |subscription| serialize(subscription) } }
    end

    def create
      subscription = current_user.alert_subscriptions.build(subscription_params)
      validate_target_access!(subscription)
      return if performed?
      subscription.save!
      AlertInboxSync.call(user: current_user)
      render json: { data: serialize(subscription.reload) }, status: :created
    rescue ActiveRecord::RecordInvalid => error
      render json: { message: error.record.errors.full_messages.to_sentence }, status: :unprocessable_content
    end

    def update
      subscription = current_user.alert_subscriptions.find(params[:id])
      subscription.assign_attributes(subscription_params)
      validate_target_access!(subscription)
      return if performed?
      subscription.save!
      AlertInboxSync.call(user: current_user)
      render json: { data: serialize(subscription.reload) }
    rescue ActiveRecord::RecordInvalid => error
      render json: { message: error.record.errors.full_messages.to_sentence }, status: :unprocessable_content
    end

    def destroy
      current_user.alert_subscriptions.find(params[:id]).destroy!
      head :no_content
    end

    private

    def subscription_params
      params.permit(:player_id, :watchlist_id, :name, :minimum_severity, :enabled, event_types: [])
    end

    def validate_target_access!(subscription)
      if subscription.player_id.present? && !Player.exists?(id: subscription.player_id)
        render json: { message: "Player was not found" }, status: :not_found
      elsif subscription.watchlist_id.present? && !current_user.admin? && !current_user.owned_watchlists.exists?(id: subscription.watchlist_id)
        render json: { message: "You are not authorized to subscribe to this watchlist" }, status: :forbidden
      end
    end

    def serialize(subscription)
      {
        id: subscription.id,
        name: subscription.name,
        minimum_severity: subscription.minimum_severity,
        event_types: subscription.event_types,
        enabled: subscription.enabled,
        target: subscription.player ? { type: "player", id: subscription.player.id, name: subscription.player.full_name } : { type: "watchlist", id: subscription.watchlist.id, name: subscription.watchlist.name },
        created_at: subscription.created_at,
        updated_at: subscription.updated_at
      }
    end
  end
end
