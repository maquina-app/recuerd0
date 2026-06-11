Rails.application.routes.draw do
  # House MD image uploads — deferred to a follow-up. Re-enable alongside the
  # uploads controller and Content#markdown_uploadable_by? wiring.
  # namespace :action_text, path: nil do
  #   get  "/u/*slug" => "markdown/uploads#show",   as: :markdown_upload
  #   post "/uploads" => "markdown/uploads#create", as: :markdown_uploads
  # end
  resource :session
  resources :passwords, param: :token

  # OAuth 2.1 Authorization Server (for the remote MCP server). Always routable.
  get "/.well-known/oauth-protected-resource", to: "oauth/well_known#protected_resource"
  get "/.well-known/oauth-protected-resource/mcp", to: "oauth/well_known#protected_resource"
  get "/.well-known/oauth-authorization-server", to: "oauth/well_known#authorization_server"

  namespace :oauth do
    post "register", to: "registrations#create"   # Dynamic Client Registration (RFC 7591)
    get "authorize", to: "authorizations#new"      # consent screen
    post "authorize", to: "authorizations#create"  # consent submit
    post "token", to: "tokens#create"              # code/refresh -> token
    post "revoke", to: "revocations#create"        # RFC 7009 revocation
  end

  # Remote MCP server endpoint (JSON-RPC 2.0 over HTTP).
  post "/mcp", to: "mcp#call"

  if Rails.application.config.multi_tenant
    resource :registration, only: %i[new create]

    # Marketing / legal pages
    get "api-docs", to: "pages#api_docs", as: :api_docs
    get "cli", to: "pages#cli", as: :cli
    get "agents", to: "pages#agents", as: :agents
    get "pricing", to: "pages#pricing", as: :pricing
    get "terms", to: "pages#terms", as: :terms
    get "privacy", to: "pages#privacy", as: :privacy
    get "license", to: "pages#license", as: :license
  end

  # First run setup — always routable, controller guards access
  resource :first_run, only: %i[new create], controller: "first_run"

  # Account management
  resource :account, only: %i[show update destroy] do
    resources :users, only: %i[destroy], controller: "account/users"
    resource :invitation, only: %i[create], controller: "account/invitations"
    resources :exports, only: %i[create show], controller: "account/exports"
  end

  # User profile
  resource :profile, only: %i[show update] do
    resource :password, only: %i[update], controller: "profile/passwords"
    resources :access_tokens, only: %i[create destroy], controller: "profile/access_tokens"
  end

  # Invitations (public — available in both modes for team member invites)
  resources :invitations, only: %i[show create], param: :token

  resources :workspaces do
    resource :context, only: %i[show], controller: "workspaces/contexts", defaults: {format: :json}

    resources :memories do
      resource :markdown, only: %i[show], controller: "memories/markdowns"
      resources :versions, only: %i[index show create], controller: "memories/versions" do
        resource :consolidation, only: %i[create], controller: "memories/versions/consolidations"
      end
      resources :links, only: %i[index create destroy], controller: "memories/links",
        defaults: {format: :json}
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

  # Cross-workspace memory browsing (API only)
  get "memories", to: "memories/browse#index", as: :browse_memories, defaults: {format: :json}

  # Search
  get "search", to: "search#index", as: :search

  # Pin routes
  post "pins/:pinnable_type/:pinnable_id", to: "pins#create", as: :create_pin
  delete "pins/:pinnable_type/:pinnable_id", to: "pins#destroy", as: :destroy_pin

  # Error pages (used by config.exceptions_app = routes)
  match "/400", to: "errors#bad_request", via: :all
  match "/404", to: "errors#not_found", via: :all
  match "/422", to: "errors#unprocessable_entity", via: :all
  match "/500", to: "errors#internal_server_error", via: :all

  get "up", to: "rails/health#show", as: :rails_health_check
  get "manifest", to: "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker", to: "rails/pwa#service_worker", as: :pwa_service_worker

  if Rails.application.config.multi_tenant
    root "home#index"
  else
    root "workspaces#index"
  end
end
