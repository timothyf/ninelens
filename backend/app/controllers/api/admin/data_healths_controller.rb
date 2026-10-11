module Api
  module Admin
    class DataHealthsController < ApplicationController
      before_action :require_authenticated_user
      before_action :require_admin_user

      def show
        include_postseason = params.key?(:include_postseason) ? ActiveModel::Type::Boolean.new.cast(params[:include_postseason]) : true
        render json: { data: AdminDataHealthCheck.call(include_postseason:) }
      end
    end
  end
end
