module Api
  class FreeAgentsController < ApplicationController
    def show
      render json: { data: FreeAgentsQuery.new(on: ApplicationCalendar.current_date).result }
    end
  end
end
