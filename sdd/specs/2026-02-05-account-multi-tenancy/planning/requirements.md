# Spec Requirements: Account Multi-Tenancy

## Initial Description

Refactor to introduce Account model as multi-tenant container. Currently User owns all resources directly (workspaces, pins, sessions). Need to add Account model where:
- Account has many Users
- User belongs to Account
- Workspace belongs to Account (not User directly)
- Memories/Contents inherit account through Workspace
- Pins remain user-scoped (within account context)
- Sessions remain user-scoped
- Add user registration flow that creates Account + User atomically on signup

No backwards compatibility needed - this is a greenfield application.

## Requirements Discussion

### Questions & Answers

**Q1:** Should one user be able to belong to multiple accounts, or is it strictly one account per user?
**A:** Strictly one account per user. This is a personal knowledge management app where each user gets their own account.

**Q2:** Should Account have a name or other identifying attributes?
**A:** Yes, Account should have a name. This name can default to the user's email or a derived name from signup.

**Q3:** When a user signs up, should they provide an account name or should it be auto-generated?
**A:** Auto-generated from the user's email (the part before @). Can be changed later.

**Q4:** Should there be any concept of account roles or permissions (admin, member)?
**A:** No. Single user per account, no roles needed. Keep it simple per Rails Simplifier principles.

**Q5:** What happens to existing user data during migration?
**A:** No backwards compatibility needed. We can reset the database or create migration that creates accounts for existing users.

**Q6:** Should the registration form be simple (email + password) or include additional fields?
**A:** Simple: email + password + password confirmation. Account created automatically.

**Q7:** Any email verification requirement for signup?
**A:** No. Keep it simple for now. Can be added later if needed.

### Existing Code to Reference

**Similar Features Identified:**
- **Authentication:** `app/controllers/sessions_controller.rb` — login flow pattern
- **Authentication concern:** `app/controllers/concerns/authentication.rb` — session management
- **User model:** `app/models/user.rb` — current associations pattern
- **Workspace model:** `app/models/workspace.rb` — ownership pattern to adapt

**Components to potentially reuse:**
- Security layout (`app/views/layouts/security.html.erb`) for registration form
- Form styling patterns from login form (`app/views/sessions/new.html.erb`)
- Flash message handling from sessions controller

**Backend logic to reference:**
- `start_new_session_for(user)` pattern for post-registration auto-login
- Model transaction patterns from `Memory.create_with_content`

## Visual Assets

### Files Provided

No visual assets provided - this is a backend-focused refactor with minimal UI (registration form follows existing login form pattern).

## Requirements Summary

### Functional Requirements

- Create Account model as tenant container
- User belongs to Account (required, single account)
- Workspace belongs to Account (move from User)
- Registration creates Account + User in single transaction
- Auto-login after successful registration
- Account name auto-generated from email, editable later

### Non-Functional Requirements

- No performance regression (simple foreign key changes)
- Maintain existing authorization model (user can only access own workspaces via account)
- Follow Rails Simplifier patterns (no unnecessary abstractions)

### Reusability Opportunities

- Security layout for registration form
- Login form styling for registration form
- `start_new_session_for` for post-registration login
- Transaction patterns from Memory model

### Scope Boundaries

**In Scope:**
- Account model with name attribute
- User belongs_to Account association
- Workspace belongs_to Account (replacing User)
- RegistrationsController for signup
- Registration form view
- Database migration for accounts table
- Update foreign keys (workspace.user_id → workspace.account_id)
- Update Current context to include account

**Out of Scope:**
- Multi-user accounts (one user per account only)
- Account roles/permissions
- Email verification
- Account settings/preferences UI (name editable via future feature)
- Team/collaboration features
- Account deletion flow (user deletion cascades)

### Technical Considerations

- Account ID should be added to workspaces, not memories (memories inherit via workspace)
- Pins remain scoped to user (polymorphic to workspace/memory within same account)
- Sessions remain user-scoped (authentication is user-level)
- Current.account derived from Current.user.account
- All workspace queries must scope to current account
- Migration should handle existing data (create account per existing user, reassign workspaces)
