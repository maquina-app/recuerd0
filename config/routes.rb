Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  resources :workspaces do
    resources :memories do
      collection do
        post :preview, to: "memories/previews#create"
      end
      resources :versions, only: [:index, :show, :create], controller: "memories/versions" do
        resource :consolidation, only: [:create], controller: "memories/versions/consolidations"
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

  # Pin routes
  post "pins/:pinnable_type/:pinnable_id", to: "pins#create", as: :create_pin
  delete "pins/:pinnable_type/:pinnable_id", to: "pins#destroy", as: :destroy_pin

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", :as => :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "home#index"
end
