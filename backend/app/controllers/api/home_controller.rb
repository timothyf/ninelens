module Api
  class HomeController < ApplicationController
    def show
      date = params[:date].presence || ApplicationCalendar.current_date
      league = params[:league].to_s.downcase
      cache_key = [ "home-snapshot/v2", date, league ]
      snapshot = Rails.cache.fetch(cache_key, expires_in: 2.minutes) do
        HomeSnapshotQuery.new(on: date, league: league).result
      end

      render json: { data: snapshot }
    end
  end
end
