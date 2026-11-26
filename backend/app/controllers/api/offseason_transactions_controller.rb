module Api
  class OffseasonTransactionsController < ApplicationController
    def show
      render json: { data: OffseasonTransactionsQuery.new(on: ApplicationCalendar.current_date).result }
    end
  end
end
