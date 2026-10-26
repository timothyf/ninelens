module Api
  class SeasonReviewController < ApplicationController
    def show
      render json: { data: SeasonReviewQuery.new(season: params[:season]).result }
    rescue ArgumentError => error
      render json: { message: error.message, errors: [ error.message ] }, status: :unprocessable_content
    end
  end
end
