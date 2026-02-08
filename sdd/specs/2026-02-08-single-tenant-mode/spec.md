# Single-Tenant Mode with First Run Setup

**Status:** Draft
**Fizzy Card:** #162
**Date:** 2026-02-08

## Problem

Recuerd0 is currently always multi-tenant: anyone can register, marketing pages are always visible, and the root route shows a landing page for unauthenticated users. For personal or team deployments, operators want to run a single-tenant instance where:

- No public registration exists
- Marketing/legal pages are hidden
- The first visit forces account creation (first run setup)
- After setup, no additional accounts can be created

## Solution

Introduce a `MULTI_TENANT_ENABLED` environment variable (default: `false`) that controls the application's tenancy mode, plus a `FirstRunController` that handles initial account creation in single-tenant mode.

## Detailed Design

### 1. Configuration Flag

**Environment variable:** `MULTI_TENANT_ENABLED`
- Default: `false` (single-tenant mode)
- Set to `"true"` to enable multi-tenant mode (current behavior)

**Implementation:** Add a configuration accessor in `config/application.rb`:

```ruby
config.multi_tenant = ENV.fetch("MULTI_TENANT_ENABLED", "false") == "true"
```

Accessible everywhere as `Rails.application.config.multi_tenant`.

Add a helper method in `ApplicationController` (available to all controllers and views):

```ruby
helper_method :multi_tenant?

def multi_tenant?
  Rails.application.config.multi_tenant
end
```

### 2. Route Changes

Wrap multi-tenant-only routes in a conditional:

```ruby
Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  if Rails.application.config.multi_tenant
    # Multi-tenant only routes
    resource :registration, only: %i[new create]
    resources :invitations, only: %i[show create], param: :token

    # Marketing / legal pages
    get "terms", to: "pages#terms", as: :terms
    get "privacy", to: "pages#privacy", as: :privacy
    get "api-docs", to: "pages#api_docs", as: :api_docs
    get "cli", to: "pages#cli", as: :cli
    get "agents", to: "pages#agents", as: :agents
  else
    # Single-tenant: first run setup
    resource :first_run, only: %i[new create]
  end

  # Account, profile, workspaces, etc. (unchanged)
  # ...

  if Rails.application.config.multi_tenant
    root "home#index"
  else
    root "workspaces#index"
  end
end
```

**Key decisions:**
- Session and password routes remain available in both modes (users still need to log in and reset passwords)
- API docs, CLI, and agents pages are marketing content — hidden in single-tenant mode
- Terms/privacy are only relevant for public registration
- The `first_run` resource is only available in single-tenant mode
- Account management routes (show/update/destroy, users, invitations, exports) remain — admin can still manage the account

### 3. FirstRunController

New controller at `app/controllers/first_run_controller.rb`:

```ruby
class FirstRunController < ApplicationController
  layout "security"

  allow_unauthenticated_access
  before_action :require_no_accounts

  def new
    @user = User.new
  end

  def create
    @user = Account.create_with_user(**registration_params)

    if @user.persisted?
      start_new_session_for @user
      redirect_to workspaces_path, notice: t(".success")
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def require_no_accounts
    redirect_to root_path if Account.exists?
  end

  def registration_params
    params.require(:user).permit(:email_address, :password, :password_confirmation).to_h.symbolize_keys
  end
end
```

**Behavior:**
- Only accessible when no accounts exist in the database
- Once an account is created, `require_no_accounts` redirects all requests to root (which is `workspaces#index`)
- Reuses `Account.create_with_user` (same as registration) — first user is admin, "Start Here" workspace seeded
- Uses the security layout (centered card, same as login)

### 4. Authentication Concern Changes

In single-tenant mode, when no account exists, unauthenticated requests should redirect to first run setup instead of the login page:

```ruby
def request_authentication
  if request.format.json?
    render_unauthorized
  elsif !Rails.application.config.multi_tenant && !Account.exists?
    redirect_to new_first_run_path
  else
    session[:return_to_after_authenticating] = request.url
    redirect_to new_session_path
  end
end
```

### 5. View Changes

#### First Run View (`app/views/first_run/new.html.erb`)

Similar to the registration form but with different copy — "Set up your instance" instead of "Create an account". No terms/privacy links. No "Already have an account?" link.

#### Session Login View

Conditionally hide "Sign up" link and terms/privacy footer in single-tenant mode:

```erb
<%# Only show sign-up link in multi-tenant mode %>
<% if multi_tenant? %>
  <div class="text-center text-sm">
    Don't have an account?
    <%= link_to "Sign up", new_registration_path, class: "underline underline-offset-4" %>
  </div>
<% end %>
```

```erb
<%# Only show terms/privacy in multi-tenant mode %>
<% if multi_tenant? %>
  <div class="text-center text-xs text-muted-foreground">
    By clicking continue, you agree to our ...
  </div>
<% end %>
```

#### Password Reset View

Same pattern — hide terms/privacy footer.

#### Home Controller

In single-tenant mode, authenticated users go to workspaces index (root route handles this). The `HomeController` is only used in multi-tenant mode.

### 6. Account Invitation Routes

In single-tenant mode, the `account/invitations` resource routes remain available (admin can still generate invitation links to add team members), but the public `invitations` routes (show/create) are disabled since they're wrapped in the multi-tenant conditional.

**Wait** — this means in single-tenant mode, the admin can generate an invitation token but there's no public endpoint to accept it. We need to keep the public invitation routes in single-tenant mode too, since the account has a 5-user limit and the admin should be able to invite team members.

**Revised:** Move invitation routes outside the multi-tenant conditional:

```ruby
# Available in both modes — admin invites team members
resources :invitations, only: %i[show create], param: :token
```

Only `registration` is disabled in single-tenant mode.

## Files to Create/Modify

| File | Action | Description |
|------|--------|-------------|
| `config/application.rb` | Modify | Add `config.multi_tenant` from ENV |
| `config/routes.rb` | Modify | Conditional routes based on multi_tenant flag |
| `app/controllers/application_controller.rb` | Modify | Add `multi_tenant?` helper |
| `app/controllers/first_run_controller.rb` | Create | First run setup controller |
| `app/controllers/concerns/authentication.rb` | Modify | Redirect to first run when no accounts |
| `app/views/first_run/new.html.erb` | Create | First run setup form |
| `app/views/sessions/new.html.erb` | Modify | Conditionally hide sign-up link and terms |
| `app/views/passwords/new.html.erb` | Modify | Conditionally hide terms footer |
| `config/locales/views/en.yml` | Modify | Add first_run translations |
| `test/controllers/first_run_controller_test.rb` | Create | Tests for first run controller |
| `test/controllers/routing_test.rb` | Create | Tests for route availability by mode |

## Testing Strategy

1. **FirstRunController tests:**
   - `GET /first_run/new` shows setup form when no accounts exist
   - `GET /first_run/new` redirects to root when an account exists
   - `POST /first_run` creates account + user and logs in
   - `POST /first_run` with invalid data re-renders form

2. **Routing tests (single-tenant mode):**
   - Registration routes return 404 / are not routable
   - Marketing pages (terms, privacy, api-docs, cli, agents) return 404
   - Root route resolves to `workspaces#index`
   - First run route is available

3. **Authentication redirect test:**
   - In single-tenant mode with no accounts, unauthenticated request redirects to first run
   - In single-tenant mode with accounts, unauthenticated request redirects to login

4. **View tests:**
   - Login page hides sign-up link in single-tenant mode
   - Login page hides terms/privacy in single-tenant mode

## Non-Goals

- No UI toggle for switching modes (ENV-only)
- No migration — purely a configuration + controller change
- No changes to the API authentication (Bearer tokens work the same regardless of mode)
- No changes to account management (admin can still manage users, export data, etc.)
