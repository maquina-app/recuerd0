# Specification: Account Multi-Tenancy

## Goal

Introduce an Account model as the multi-tenant container for the application, enabling proper data isolation and preparing the architecture for future multi-user scenarios while adding self-service user registration.

## User Stories

- As a new user, I want to sign up with my email and password so that I can start using the application
- As a user, I want my workspaces to belong to my account so that my data is properly isolated
- As a user, I want to be automatically logged in after registration so that I can start using the app immediately

## Specific Requirements

**Account Model**
- Create `accounts` table with `name` (string, required) and timestamps
- Account `has_many :users, dependent: :destroy`
- Account `has_many :workspaces, dependent: :destroy`
- Account name auto-generated from user's email (part before @)

**User Model Changes**
- Add `account_id` foreign key to users table (required)
- User `belongs_to :account`
- Remove direct workspace association from User
- Keep `has_many :sessions` and `has_many :pins` on User

**Workspace Model Changes**
- Replace `user_id` with `account_id` foreign key
- Workspace `belongs_to :account`
- Remove `belongs_to :user` association
- Keep all existing concerns (SoftDeletable, Archivable, Pinnable)

**Current Context**
- Add `Current.account` derived from `Current.user&.account`
- Update controller helpers to scope by account

**Registration Flow**
- Create `RegistrationsController` with `new` and `create` actions
- `POST /registration` creates Account + User in transaction
- Auto-login via `start_new_session_for(user)` after successful registration
- Redirect to workspaces_path after registration
- Rate limit registration to 10 attempts per hour

**Registration Form**
- Fields: email_address, password, password_confirmation
- Use security layout (same as login)
- Follow login form styling patterns
- Link to login page for existing users
- Display validation errors inline

**Controller Scoping**
- WorkspacesController scopes all queries to `Current.account.workspaces`
- Namespaced controllers (archives, deleted) scope to account
- MemoriesController loads workspace scoped to account

**Database Migration**
- Create accounts table
- Add account_id to users (required after migration)
- Replace workspace.user_id with workspace.account_id
- Migration creates account for each existing user
- Migration reassigns workspaces to user's new account

## Existing Code to Leverage

**Sessions Controller Pattern**
- `app/controllers/sessions_controller.rb` — login flow, security layout, flash messages
- `app/controllers/concerns/authentication.rb` — `start_new_session_for`, rate limiting

**Login Form UI**
- `app/views/sessions/new.html.erb` — form structure, styling, links
- `app/views/layouts/security.html.erb` — centered card layout

**Transaction Pattern**
- `app/models/memory.rb` — `create_with_content` transaction pattern for atomic Account + User creation

**Controller Concerns**
- `app/controllers/concerns/workspace_scoped.rb` — pattern for scoping to workspace

## Out of Scope

- Multi-user accounts (future feature)
- Account roles or permissions
- Email verification for registration
- Account settings UI (name editing)
- Team/collaboration features
- Invitation system
- Account switching
- Account deletion (cascade from user deletion)
