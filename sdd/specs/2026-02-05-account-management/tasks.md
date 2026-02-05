# Tasks: Account Management

## Overview

- **Spec:** 2026-02-05-account-management
- **Total Task Groups:** 6
- **Estimated Effort:** M (1 week)
- **Status:** In Progress

---

## Task Groups

### Database Layer

#### Task Group 1: User Roles, Account Soft Delete & User Limit
**Dependencies:** None

- [ ] 1.0 Complete database layer for user roles, account soft delete, and user limits
  - [ ] 1.1 Write tests for model changes
    - Test User role validation (admin, member only)
    - Test User#admin? and User#member? convenience methods
    - Test Account.create_with_user sets first user as admin
    - Test Account includes SoftDeletable (soft_delete, restore, deleted?)
    - Test Account#at_user_limit? returns true when 5 active users exist
    - Test Account#generate_invitation_token creates a valid encrypted token
    - Test Account#find_by_invitation_token validates token (valid, expired, wrong account)
    - Test Account#anonymize_users! replaces all user emails with deleted-xxx pattern
  - [ ] 1.2 Create migration: add role to users, add deleted_at to accounts
    - `users.role` — string, not null, default: `"member"`, indexed
    - `accounts.deleted_at` — datetime, nullable, indexed
    - Data migration: set existing users to `"admin"` (they are account creators)
  - [ ] 1.3 Update User model
    - Add `ROLES = %w[admin member].freeze`
    - Add validation: `validates :role, presence: true, inclusion: { in: ROLES }`
    - Add `admin?` and `member?` methods
    - Add `anonymize_email!` method (replaces name part with `deleted-<hex>`)
    - Add `anonymized?` method (checks if email starts with "deleted-")
  - [ ] 1.4 Update Account model
    - Include SoftDeletable concern
    - Add `USER_LIMIT = 5` constant
    - Add `at_user_limit?` method (counts non-anonymized users)
    - Add `active_users` scope/method (excludes anonymized users)
    - Add `active_users_count` method
    - Add `generate_invitation_token` method (MessageEncryptor, 7-day expiry)
    - Add `self.find_by_invitation_token(token)` class method (decrypt, validate)
    - Add `anonymize_users!` method (anonymizes all users, destroys all sessions)
    - Update `create_with_user` to set `role: "admin"` on first user
  - [ ] 1.5 Update seeds
    - Set demo user role to `"admin"`
  - [ ] 1.6 Update fixtures
    - Add `role: admin` to user `one`
    - Add `role: member` to user `two` (or add a member user to account `one` for testing)
    - Add a third user fixture: `member` (account: one, role: member) for removal tests
  - [ ] 1.7 Ensure database layer tests pass
    - Run ONLY tests from 1.1

**Acceptance Criteria:**
- [ ] All tests from 1.1 pass
- [ ] Migration runs and rolls back successfully
- [ ] SoftDeletable works on Account
- [ ] Role validation works on User
- [ ] Invitation token generation and validation work
- [ ] Email anonymization works correctly
- [ ] Seeds and fixtures updated

---

### Controller Layer

#### Task Group 2: AccountsController (Settings & Deletion)
**Dependencies:** Task Group 1

- [ ] 2.0 Complete AccountsController implementation
  - [ ] 2.1 Write controller tests
    - Test `show` renders account page for authenticated admin
    - Test `show` renders read-only view for authenticated member
    - Test `update` updates account name for admin
    - Test `update` rejects request from member (forbidden)
    - Test `update` rejects invalid params (blank name)
    - Test `destroy` soft-deletes account for admin, anonymizes emails, destroys sessions, redirects
    - Test `destroy` rejects request from member (forbidden)
    - Test unauthenticated access redirects to login
  - [ ] 2.2 Create AccountsController
    - `show` — loads Current.account with active users, passes `admin: Current.user.admin?` to view
    - `update` — requires admin, updates account name, redirects with toast
    - `destroy` — requires admin, soft-deletes account, anonymizes users, destroys all sessions, redirects to root
    - Add `require_admin` before_action for `update` and `destroy`
    - Strong params: `account_params` permits `:name`
  - [ ] 2.3 Add routes
    - `resource :account, only: [:show, :update, :destroy]` (singular resource)
  - [ ] 2.4 Ensure controller tests pass
    - Run ONLY tests from 2.1

**Acceptance Criteria:**
- [ ] All tests from 2.1 pass
- [ ] Admin can view, update, and delete account
- [ ] Member can only view (read-only)
- [ ] Authorization enforced (admin-only for mutation actions)
- [ ] Deletion cascades to email anonymization and session destruction

---

#### Task Group 3: User Management (Removal & Invitations)
**Dependencies:** Task Groups 1, 2

- [ ] 3.0 Complete user management controllers
  - [ ] 3.1 Write controller tests
    - Test `account/users#destroy` anonymizes user email and destroys their sessions (admin)
    - Test `account/users#destroy` prevents admin from removing themselves
    - Test `account/users#destroy` prevents member from removing users
    - Test `account/invitations#create` generates invitation token and redirects (admin)
    - Test `account/invitations#create` fails when at user limit
    - Test `account/invitations#create` rejects member request
    - Test `invitations#show` renders registration form for valid token
    - Test `invitations#show` renders error for expired/invalid token
  - [ ] 3.2 Create Account::UsersController
    - Namespace under `account/` (singular, matching `resource :account`)
    - `destroy` — requires admin, anonymizes user email, destroys their sessions, redirect to account
    - Cannot remove self
    - Cannot remove other admins (future-proofing)
  - [ ] 3.3 Create Account::InvitationsController
    - Namespace under `account/` (singular)
    - `create` — requires admin, generates invitation token, redirects to account with token in flash
    - Blocked when at user limit
  - [ ] 3.4 Create InvitationsController (public)
    - `show` — decrypts token, validates, renders registration form with `role: "member"`
    - `create` — creates user under invited account with `role: "member"`, starts session, redirects
    - Handles expired/invalid tokens with error view
    - Uses security layout
  - [ ] 3.5 Add routes
    - Nested under `resource :account`: `resources :users, only: [:destroy], controller: "account/users"` and `resource :invitation, only: [:create], controller: "account/invitations"`
    - Top-level: `resources :invitations, only: [:show, :create], param: :token`
  - [ ] 3.6 Update Authentication concern
    - After resolving user, check `Current.account&.deleted?`
    - If deleted, destroy session, redirect to login with "Account has been deleted" flash
    - Bearer token auth: check account deletion, return 401 if deleted
  - [ ] 3.7 Ensure controller tests pass
    - Run ONLY tests from 3.1

**Acceptance Criteria:**
- [ ] All tests from 3.1 pass
- [ ] User removal works with email anonymization (admin only)
- [ ] Admin protection (can't remove self, members can't remove anyone)
- [ ] Invitation generation respects user limit (admin only)
- [ ] Invitation acceptance creates user with `role: "member"` under correct account
- [ ] Deleted account blocks login

---

### Frontend Layer

#### Task Group 4: Account Page Views
**Dependencies:** Task Groups 2, 3

- [ ] 4.0 Complete account page UI
  - [ ] 4.1 Write system/integration tests
    - Test account page renders all sections for admin (name form, users, invitations, danger zone)
    - Test account page renders read-only view for member (name display, users list only)
    - Test account name update via form submission (admin)
    - Test user list shows role badges (admin/member)
    - Test invitation link generation and display (admin)
  - [ ] 4.2 Create account show view (`app/views/accounts/show.html.erb`)
    - Page title: "Account"
    - Breadcrumb: "Account" (top-level, no parent)
    - Container: `mx-auto max-w-4xl space-y-6`
    - Conditionally render sections based on `Current.user.admin?`
  - [ ] 4.3 Create account details partial
    - Admin: Card with editable form (name input, submit button)
    - Member: Card with read-only account name display
    - Card header: "Account Settings" / "Manage your account name and details"
  - [ ] 4.4 Create users section partial
    - Card with header: "Users" / "X of 5 users in this account"
    - User rows: avatar, email, join date, role badge
    - Admin badge: `:default` variant. Member badge: `:secondary` variant
    - Remove button (admin view only, on non-admin users): ghost destructive, turbo_confirm
    - Separator between rows
  - [ ] 4.5 Create invitations section partial (admin only)
    - Card with header: "Invite Users" / "Generate a shareable link for new members"
    - Generate button (disabled when at limit)
    - Display generated URL in a read-only input with copy hint
    - Show "Expires in 7 days" text
    - Show limit indicator when at capacity
  - [ ] 4.6 Create danger zone section partial (admin only)
    - Card with `border-destructive` styling
    - Card header: "Delete Account" in destructive text color
    - Warning alert (variant: :warning, icon: :alert_triangle)
    - Delete button (variant: destructive, turbo_confirm with full warning text)
  - [ ] 4.7 Ensure UI tests pass
    - Run ONLY tests from 4.1

**Acceptance Criteria:**
- [ ] All tests from 4.1 pass
- [ ] Admin sees all four sections with edit capabilities
- [ ] Member sees read-only account name and user list only
- [ ] Role badges display correctly
- [ ] Forms submit and show feedback
- [ ] Matches existing UI patterns (cards, data-component, badges, alerts)

---

#### Task Group 5: Invitation Registration & Sidebar Link
**Dependencies:** Task Groups 3, 4

- [ ] 5.0 Complete invitation views and sidebar wiring
  - [ ] 5.1 Write tests
    - Test invitation show page renders registration form with account name
    - Test invitation error page renders for invalid/expired tokens
    - Test sidebar "Account" link points to account_path
  - [ ] 5.2 Create invitation show view (`app/views/invitations/show.html.erb`)
    - Security layout (centered card, like registration)
    - Show account name: "Join [Account Name]"
    - Registration form (email, password, password_confirmation)
    - Hidden field for invitation token
    - Submit button: "Create Account & Join"
  - [ ] 5.3 Create invitation error view (`app/views/invitations/error.html.erb`)
    - Security layout
    - Alert: "This invitation link is invalid or has expired"
    - Link to regular registration
  - [ ] 5.4 Update sidebar nav_user dropdown
    - Change `href: "#"` to `href: account_path` for Account link
  - [ ] 5.5 Update terms of service
    - Section 7: Add sentence about 30-day retention after account closure
  - [ ] 5.6 Add i18n keys for all flash messages
    - Account update success/error, deletion, user removal, invitation generation
  - [ ] 5.7 Ensure tests pass
    - Run ONLY tests from 5.1

**Acceptance Criteria:**
- [ ] All tests from 5.1 pass
- [ ] Invitation registration works end-to-end
- [ ] Sidebar link navigates to account page
- [ ] Terms of service updated
- [ ] Flash messages use i18n

---

### Testing & Verification

#### Task Group 6: Test Review & Gap Analysis
**Dependencies:** Task Groups 1-5

- [ ] 6.0 Review and fill critical test gaps
  - [ ] 6.1 Review all tests from Groups 1-5
    - Database tests: 8 (from 1.1)
    - AccountsController tests: 8 (from 2.1)
    - User management/invitation tests: 8 (from 3.1)
    - UI tests: 5 (from 4.1)
    - Invitation views/sidebar tests: 3 (from 5.1)
    - Total existing: 32
  - [ ] 6.2 Identify critical gaps
    - Authentication blocking for deleted accounts (session + token)
    - Edge case: invitation acceptance when account reaches limit during token validity
    - Edge case: user removal when user has active API tokens
    - Role enforcement across all admin-only actions
  - [ ] 6.3 Add up to 6 strategic tests
    - Test login blocked when account is soft-deleted (session auth)
    - Test API request blocked when account is soft-deleted (token auth)
    - Test invitation acceptance fails when account at limit
    - Test removed user's API tokens stop working (account.deleted? check)
    - Test account deletion destroys all sessions across all users
    - Test member cannot access any admin-only actions (comprehensive)
  - [ ] 6.4 Run full feature test suite
    - Run tests from all groups
    - Run `bin/rails test` for full regression
    - Run `bundle exec standardrb` for lint check

**Acceptance Criteria:**
- [ ] All feature-specific tests pass
- [ ] Full test suite passes (no regressions)
- [ ] Lint passes
- [ ] Critical workflows covered
- [ ] Role enforcement verified

---

## Execution Order

1. Database Layer (Task Group 1) — Migration, model changes, seeds, fixtures
2. AccountsController (Task Group 2) — Core CRUD with role enforcement
3. User Management & Invitations (Task Group 3) — Controllers, auth updates
4. Account Page Views (Task Group 4) — UI with admin/member distinction
5. Invitation Views & Sidebar (Task Group 5) — Public pages, wiring, i18n
6. Testing & Verification (Task Group 6) — Gap analysis, regression

---

## Progress Log

| Date | Task | Status | Notes |
|------|------|--------|-------|
