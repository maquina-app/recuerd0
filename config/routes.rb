Rails.application.routes.draw do
  resource :session
  resource :registration, only: %i[new create]
  resources :passwords, param: :token

  # Account management
  resource :account, only: %i[show update destroy] do
    resources :users, only: %i[destroy], controller: "account/users"
    resource :invitation, only: %i[create], controller: "account/invitations"
  end

  # Invitations (public)
  resources :invitations, only: %i[show create], param: :token

  # Legal pages
  get "terms", to: "pages#terms", as: :terms
  get "privacy", to: "pages#privacy", as: :privacy

  resources :workspaces do
    resources :memories do
      collection do
        post :preview, to: "memories/previews#create"
      end
      resources :versions, only: %i[index show create], controller: "memories/versions" do
        resource :consolidation, only: %i[create], controller: "memories/versions/consolidations"
      end
    end

    collection do
      get :archived, to: "workspaces/archives#index"
      get :deleted, to: "workspaces/deleted#index"
    end

    member do
      post :archive, to: "workspaces/archives#create"
      delete :archive, to: "workspaces/archives#destroy"
    end
  end

  # Archived & deleted workspace routes
  scope "workspaces" do
    get "archived/:id", to: "workspaces/archives#show", as: :archived_workspace
    get "deleted/:id", to: "workspaces/deleted#show", as: :deleted_workspace
    post "deleted/:id/restore", to: "workspaces/restores#create", as: :restore_deleted_workspace
    delete "deleted/:id", to: "workspaces/deleted#destroy", as: :destroy_deleted_workspace
  end

  # Pinned memories
  get "memories/pinned", to: "memories/pinned#index", as: :pinned_memories

  # Search
  get "search", to: "search#index", as: :search

  # Pin routes
  post "pins/:pinnable_type/:pinnable_id", to: "pins#create", as: :create_pin
  delete "pins/:pinnable_type/:pinnable_id", to: "pins#destroy", as: :destroy_pin

  get "up", to: "rails/health#show", as: :rails_health_check
  get "manifest", to: "rails/pwa#manifest", as: :pwa_manifest

  root "home#index"
end
