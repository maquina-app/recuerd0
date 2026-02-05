# Tasks: Account Multi-Tenancy

## Overview

- **Spec:** 2026-02-05-account-multi-tenancy
- **Total Task Groups:** 5
- **Estimated Effort:** M (1 week)
- **Status:** Complete
- **Fizzy Card:** #146

---

## Task Groups

### Database Layer

#### Task Group 1: Account Model and Schema Changes
**Dependencies:** None

- [x] 1.0 Complete database layer implementation
  - [x] 1.1 Write 4 focused tests for Account model and associations
    - Test Account validates presence of name
    - Test Account has_many users
    - Test Account has_many workspaces
    - Test User belongs_to account (required)
  - [x] 1.2 Create accounts migration
    - Fields: name (string, required), timestamps
  - [x] 1.3 Create Account model
    - Validates: presence of name
    - has_many :users, dependent: :destroy
    - has_many :workspaces, dependent: :destroy
  - [x] 1.4 Add account_id to users migration
    - Add account_id foreign key (required)
    - Add index on account_id
  - [x] 1.5 Update User model
    - Add belongs_to :account
    - Remove has_many :workspaces
  - [x] 1.6 Migrate workspaces from user_id to account_id
    - Add account_id to workspaces
    - Create data migration to assign workspaces to user's account
    - Remove user_id from workspaces
  - [x] 1.7 Update Workspace model
    - Change belongs_to :user to belongs_to :account
  - [x] 1.8 Ensure database layer tests pass

**Acceptance Criteria:**
- [x] All tests from 1.1 pass
- [x] Migrations run successfully
- [x] Account model validations work correctly
- [x] User and Workspace associations function properly

---

### Registration Flow

#### Task Group 2: Registration Controller and Routes
**Dependencies:** Task Group 1

- [x] 2.0 Complete registration flow implementation
  - [x] 2.1 Write 5 focused tests for registration
    - Test GET /registration/new renders form
    - Test POST /registration with valid params creates Account + User
    - Test POST /registration auto-logs in user
    - Test POST /registration with invalid params re-renders form with errors
    - Test POST /registration with existing email shows error
  - [x] 2.2 Add registration routes
    - GET /registration/new → registrations#new
    - POST /registration → registrations#create
  - [x] 2.3 Create RegistrationsController
    - Include rate limiting (10 per hour)
    - allow_unauthenticated_access for new and create
    - new action renders form
    - create action builds Account + User in transaction
  - [x] 2.4 Implement Account.create_with_user class method
    - Wrap in transaction
    - Generate account name from email (part before @)
    - Create Account, then User with account_id
    - Return user on success, invalid user with errors on failure
  - [x] 2.5 Add auto-login after registration
    - Reuse start_new_session_for(user) from Authentication concern
    - Redirect to workspaces_path
  - [x] 2.6 Ensure registration tests pass

**Acceptance Criteria:**
- [x] All tests from 2.1 pass
- [x] Registration creates Account + User atomically
- [x] Failed registration shows errors without creating partial records
- [x] Auto-login works after successful registration

---

### Frontend Layer

#### Task Group 3: Registration Form and Current Context
**Dependencies:** Task Group 2

- [x] 3.0 Complete UI and context implementation
  - [x] 3.1 Write 3 focused tests for UI
    - Test registration form renders all required fields (covered in 2.1)
    - Test registration form shows validation errors (covered in 2.1)
    - Test login page links to registration
  - [x] 3.2 Create registration form view
    - Reuse security layout
    - Follow login form styling
    - Fields: email_address, password, password_confirmation
    - Link to login page for existing users
  - [x] 3.3 Add link to registration from login page
    - Updated "Sign up" link to point to new_registration_path
  - [x] 3.4 Update Current model
    - Add account method: `def account; user&.account; end`
  - [x] 3.5 Ensure UI tests pass

**Acceptance Criteria:**
- [x] All tests from 3.1 pass
- [x] Registration form matches login form styling
- [x] Current.account accessible throughout app
- [x] Navigation between login/registration works

---

### Controller Scoping

#### Task Group 4: Update Controllers to Scope by Account
**Dependencies:** Task Group 3

- [x] 4.0 Complete controller scoping
  - [x] 4.1 Scoping tests (covered by existing controller tests)
    - WorkspacesController returns only account workspaces
    - Controllers properly scoped to account
  - [x] 4.2 Update WorkspacesController
    - Changed Current.user.workspaces to Current.account.workspaces
    - Updated index, new, create actions
  - [x] 4.3 Update WorkspaceScoped concern
    - Changed set_workspace to use Current.account.workspaces
  - [x] 4.4 Update MemoriesController
    - Already uses WorkspaceScoped concern
  - [x] 4.5 Update namespaced workspace controllers
    - Workspaces::ArchivesController
    - Workspaces::DeletedController
  - [x] 4.6 Update any other controllers loading workspaces
    - SearchController - updated to use account_id
    - PinsController - updated to use Current.account.workspaces
    - Home view - updated to use Current.account.workspaces
  - [x] 4.7 Ensure scoping tests pass

**Acceptance Criteria:**
- [x] All tests pass
- [x] Users can only access their account's workspaces
- [x] All workspace-related controllers properly scoped

---

### Testing & Verification

#### Task Group 5: Test Review & Gap Analysis
**Dependencies:** Task Groups 1-4

- [x] 5.0 Review and fill critical test gaps
  - [x] 5.1 Review all tests from Groups 1-4
    - Account model tests: 4
    - Registration controller tests: 5
    - Session controller tests: 3
    - Total new tests: 12
  - [x] 5.2 Existing tests updated for account scoping
    - User model tests updated
    - Workspace model tests updated
  - [x] 5.3 All existing controller tests pass
    - 53 controller tests passing
  - [x] 5.4 Full test suite passes
    - 87 tests, 0 failures, 0 errors

**Acceptance Criteria:**
- [x] All feature-specific tests pass
- [x] Critical workflows covered
- [x] Full test suite passes (87 tests)

---

## Execution Order

1. Database Layer (Task Group 1) ✅
2. Registration Flow (Task Group 2) ✅
3. Frontend Layer (Task Group 3) ✅
4. Controller Scoping (Task Group 4) ✅
5. Testing & Verification (Task Group 5) ✅

---

## Progress Log

| Date | Task | Status | Notes |
|------|------|--------|-------|
| 2026-02-05 | Task Group 1 | ✅ Complete | Account model, migrations, fixtures |
| 2026-02-05 | Task Group 2 | ✅ Complete | RegistrationsController, routes, translations |
| 2026-02-05 | Task Group 3 | ✅ Complete | Registration form, Current.account |
| 2026-02-05 | Task Group 4 | ✅ Complete | All controllers scoped to account |
| 2026-02-05 | Task Group 5 | ✅ Complete | 87 tests passing |
