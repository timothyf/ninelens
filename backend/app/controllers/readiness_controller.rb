class ReadinessController < ActionController::API
  def show
    check_database!

    render json: {
      status: "ok",
      checks: {
        application: "ok",
        database: "ok"
      }
    }
  rescue ActiveRecord::ActiveRecordError => error
    Rails.logger.warn("Readiness check failed: database unavailable (#{error.class})")
    render json: {
      status: "unavailable",
      checks: {
        application: "ok",
        database: "unavailable"
      }
    }, status: :service_unavailable
  ensure
    response.set_header("Cache-Control", "no-store")
  end

  private

  def check_database!
    ActiveRecord::Base.connection_pool.with_connection do |connection|
      connection.select_value("SELECT 1 AS readiness")
    end
  end
end
