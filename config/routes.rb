Rails.application.routes.draw do
  devise_for :users, controllers: { registrations: "users/registrations" }
  patch "users/notifications", to: "users/notifications#update", as: :user_notifications
  patch "users/language", to: "users/languages#update", as: :user_language
  resources :notifications, only: %i[index show] do
    patch :read_all, on: :collection
    get :panel, on: :collection
  end

  # Tickets are addressed by their number (Ticket#to_param).
  # The kanban board (specs/board.md); before resources so "board" is no number.
  get "tickets/board" => "boards#show", as: :board
  # Statistics for staff (specs/reports.md).
  get "reports" => "reports#show", as: :reports

  resources :tickets, only: %i[index show new create update] do
    member do
      patch :resolve
      patch :assign
      patch :move
    end
    resources :comments, only: %i[create edit update] do
      patch :markdown, on: :member
      patch :task, on: :member
    end
    resources :revisions, only: [] do
      post :restore, on: :member
    end
    resource :description, only: %i[edit update], controller: "ticket_descriptions" do
      patch :markdown
      patch :task
    end
    resource :share, only: %i[create destroy], controller: "ticket_shares"
    resources :translations, only: :create
    resources :attachments, only: :show do
      get :preview, on: :member
    end
  end

  namespace :admin do
    root "dashboard#show"
    resources :users, except: :show do
      resource :impersonation, only: :create
    end
    resources :organizations do
      resources :memberships, only: :create
      post :mail_test, on: :member
      post :mailbox_check, on: :member
    end
    resources :memberships, only: :destroy
    resources :messages, only: %i[new create]
    resource :settings, only: %i[show update]
    # Google accounts for organization mail (specs/mail-oauth.md).
    get "organizations/:organization_id/mail_oauth/google" => "mail_oauth#start", as: :organization_google_connect
    delete "organizations/:organization_id/mail_oauth" => "mail_oauth#destroy", as: :organization_mail_oauth
    get "mail_oauth/callback" => "mail_oauth#callback", as: :mail_oauth_callback
    resources :stages, only: %i[create update destroy] do
      patch :move, on: :member
    end
  end

  # Shared tickets, no sign-in (specs/sharing.md).
  get "s/:token" => "shared_tickets#show", as: :shared_ticket
  post "s/:token" => "shared_tickets#unlock", as: :unlock_shared_ticket
  get "s/:token/files/:id" => "shared_tickets#file", as: :shared_ticket_file
  get "s/:token/files/:id/preview" => "shared_tickets#file_preview", as: :shared_ticket_file_preview

  # Public request pages of organizations (specs/public-form.md).
  get "support/:slug" => "public_requests#show", as: :public_request
  post "support/:slug" => "public_requests#create"
  get "support/:slug/thanks" => "public_requests#thanks", as: :public_request_thanks

  # One-time sign-in links (specs/public-form.md "Magic sign-in links").
  resources :magic_links, only: %i[new create], path: "magic"
  get "magic/:token" => "magic_links#show", as: :magic_link
  post "magic/:token" => "magic_links#create_session", as: :magic_link_session

  delete "impersonation" => "impersonations#destroy", as: :impersonation
  # The only page of a requester without an organization (specs/roles.md).
  get "no-organization" => "no_organizations#show", as: :no_organization

  patch "preferences" => "preferences#update", as: :preferences

  # Health check for load balancers and container orchestrators.
  get "up" => "rails/health#show", as: :rails_health_check

  root "tickets#index"
end
