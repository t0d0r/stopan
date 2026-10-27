Rails.application.routes.draw do
  devise_for :users, controllers: { registrations: "users/registrations" }
  patch "users/notifications", to: "users/notifications#update", as: :user_notifications
  resources :notifications, only: %i[index show] do
    patch :read_all, on: :collection
    get :panel, on: :collection
  end

  # Tickets are addressed by their number (Ticket#to_param).
  resources :tickets, only: %i[index show new create update] do
    member do
      patch :resolve
      patch :assign
    end
    resources :comments, only: %i[create edit update]
    resource :description, only: %i[edit update], controller: "ticket_descriptions"
    resource :share, only: %i[create destroy], controller: "ticket_shares"
    resources :attachments, only: :show do
      get :preview, on: :member
    end
  end

  namespace :admin do
    root "dashboard#show"
    resources :users, except: :show
    resources :organizations do
      resources :memberships, only: :create
    end
    resources :memberships, only: :destroy
  end

  # Shared tickets, no sign-in (specs/sharing.md).
  get "s/:token" => "shared_tickets#show", as: :shared_ticket
  post "s/:token" => "shared_tickets#unlock", as: :unlock_shared_ticket
  get "s/:token/files/:id" => "shared_tickets#file", as: :shared_ticket_file
  get "s/:token/files/:id/preview" => "shared_tickets#file_preview", as: :shared_ticket_file_preview

  patch "preferences" => "preferences#update", as: :preferences

  # Health check for load balancers and container orchestrators.
  get "up" => "rails/health#show", as: :rails_health_check

  root "tickets#index"
end
