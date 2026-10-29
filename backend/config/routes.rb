Rails.application.routes.draw do
  namespace :api do
    post "auth/register", to: "auth#register"
    post "auth/login", to: "auth#login"
    get "auth/me", to: "auth#me"
    patch "auth/password", to: "auth#update_password"
    delete "auth/logout", to: "auth#logout"
    namespace :admin do
      resource :automation_setting, only: [ :show, :update ]
      resource :data_health, only: :show do
        post :cancel, on: :collection
      end
      resources :users, only: [ :index, :create, :update ] do
        member do
          post :reset_access
        end
      end
      resources :task_runs, only: [ :index, :show, :create ] do
        collection do
          get :estimate
        end
        member do
          post :cancel
        end
      end
      resources :tasks, only: [:index], param: :task_name do
        member do
          post :run
        end
      end
    end

    resources :players, only: [:index, :show] do
      collection do
        get :compare
      end
    end
    resources :users, only: [ :index ]
    resources :teams, only: [:index, :show] do
      member { get :stats_summary }
      resources :opponent_reports, only: [ :index, :create ]
      resources :lineup_scenarios, only: [ :index, :create ] do
        collection { post :recommend }
      end
    end
    resources :opponent_reports, only: [ :show, :update ] do
      member do
        get :audit_history
        post :refresh
      end
    end
    resources :lineup_scenarios, only: [ :show, :update ] do
      member { get :audit_history }
    end
    resources :need_profiles
    resources :saved_analyses
    resources :notes, only: [ :index, :show, :create, :update, :destroy ] do
      member { get :history }
    end
    resources :tags, only: [ :index, :create ]
    resources :watchlists, only: [ :index, :show, :create, :update ] do
      resources :watchlist_entries, only: [ :create ]
      member do
        get :discovery
        get :audit_history
      end
    end
    resources :watchlist_entries, only: [ :update, :destroy ] do
      member do
        post :recalculate
        post :transition
        get :alternatives
        get :audit_history
      end
    end
    resources :alert_subscriptions, only: [ :index, :create, :update, :destroy ]
    resources :alerts, only: [ :index, :show ] do
      collection { get :digest, to: "alert_digest#show"; patch :digest, to: "alert_digest#update" }
      member do
        post :acknowledge
        post :snooze
        post :assign
        post :resolve
      end
    end
    resource :alert_digest, only: [ :show, :update ], controller: :alert_digest
    resource :home, only: [:show], controller: :home
    resource :standings, only: [:show], controller: :standings
    resource :postseason, only: [:show], controller: :postseason
    resource :season_review, only: [:show], controller: :season_review
    get "season_review/awards", to: "season_awards#show"
    resources :positions, only: [:index]
    resources :games, only: [:index, :show] do
      collection do
        get :upcoming
      end
    end
    resources :schedules, only: [:show]
    resources :roster_snapshots, only: [:index]
    resources :team_memberships, only: [] do
      collection do
        get :active_today
        get :active_range
        get :roster_status
      end
    end
    resources :player_season_stats do
      collection do
        post :import
        post :download
      end
    end
    resources :pitch_data, only: [:index] do
      collection do
        post :import
      end
    end
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Report application and database readiness for container and uptime monitoring.
  get "up" => "readiness#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
end
