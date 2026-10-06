module Api
  class PostseasonController < ApplicationController
    def show
      render json: { data: PostseasonSnapshotQuery.new(season: params[:season]).result }
    rescue ArgumentError => error
      render json: { message: error.message, errors: [error.message] }, status: :unprocessable_content
    end
  end
end
