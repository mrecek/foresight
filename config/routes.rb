Rails.application.routes.draw do
  # Setup & Auth
  get "setup", to: "setup#new"
  post "setup", to: "setup#create"
  get "login", to: "sessions#new"
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"

  root "dashboard#index"

  resources :accounts do
    member do
      patch :reconcile
    end
  end
  resources :recurring_rules
  resources :transactions do
    member do
      get :confirm_actual
      patch :mark_actual
    end
  end
  resource :settings, only: [ :edit, :update ]

  # Category management (Settings section)
  resources :category_groups do
    resources :categories, except: [ :index, :show ]
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
