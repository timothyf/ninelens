module Api
  module Admin
    class DataHealthsController < ApplicationController
      before_action :require_authenticated_user
      before_action :require_admin_user

      def show
        include_postseason = params.key?(:include_postseason) ? ActiveModel::Type::Boolean.new.cast(params[:include_postseason]) : true
        render json: { data: AdminDataHealthCheck.call(include_postseason:, cancellation_key: params[:cancellation_key]) }
      rescue ActiveRecord::QueryCanceled
        render json: { message: "Data health check canceled." }, status: :conflict
      end

      def cancel
        cancellation_key = params[:cancellation_key].to_s
        backend_pid = Rails.cache.read(AdminDataHealthCheck.cancellation_cache_key(cancellation_key)) if cancellation_key.match?(/\A[0-9a-f-]{36}\z/i)
        canceled = backend_pid.present? && ActiveRecord::Base.connection.select_value(
          ActiveRecord::Base.send(:sanitize_sql_array, ["SELECT pg_cancel_backend(?)", backend_pid])
        )
        render json: { canceled: canceled == true || canceled == "t" }
      end
    end
  end
end
