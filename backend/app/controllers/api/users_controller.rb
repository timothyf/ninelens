module Api
  class UsersController < ApplicationController
    before_action :require_authenticated_user

    def index
      users = User.active.where(system_account: false).order(:name, :email)
      render json: { data: users.map { |user| UserSummarySerializer.call(user) } }
    end
  end
end
