Rails.application.routes.draw do
  namespace :api do
    post "auth/register", to: "auth#register"
    post "auth/login", to: "auth#login"
    get "auth/me", to: "auth#me"
    delete "auth/logout", to: "auth#logout"
    namespace :admin do
      resource :data_health, only: :show
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

    resources :players, only: [:index, :show]
    resources :users, only: [ :index ]
    resources :teams, only: [:index, :show] do
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
        post :download
      end
    end
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
end
