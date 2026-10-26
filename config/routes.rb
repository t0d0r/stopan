Rails.application.routes.draw do
  devise_for :users, controllers: { registrations: "users/registrations" }
  patch "users/notifications", to: "users/notifications#update", as: :user_notifications

  # Tickets are addressed by their number (Ticket#to_param).
  resources :tickets, only: %i[index show new create update] do
    member do
      patch :resolve
      patch :assign
    end
    resources :comments, only: :create
    resources :attachments, only: :show
  end

  namespace :admin do
    root "dashboard#show"
    resources :users, except: :show
    resources :organizations do
      resources :memberships, only: :create
    end
    resources :memberships, only: :destroy
  end

  patch "preferences" => "preferences#update", as: :preferences

  # Health check for load balancers and container orchestrators.
  get "up" => "rails/health#show", as: :rails_health_check

  root "tickets#index"
end
