# Spec Requirements: Account Management

## Initial Description

Implement the account management page accessible from the sidebar user dropdown "Account" link. The page allows account admins to: edit the account name, view users in the account, generate invitation links for new users to join, remove users from the account, and delete the account. Introduces a user role system (admin/member) for access control. Follows existing UI patterns with maquina-components.

## Requirements Discussion

### Questions & Answers

**Q1:** For the invitation system: should invite links have a configurable expiration (e.g., 7 days default), or a fixed expiration? And should there be a limit on how many users can join an account?
**A:** 7-day expiry, with a limit on users per account.

**Q2:** What should the maximum number of users per account be?
**A:** 5 users per account.

**Q3:** For the user list on the account page: should the account owner be able to remove other users from the account, or is this read-only for now?
**A:** Remove users allowed. Account admin can remove users from the account.

**Q4:** When an account admin removes a user, what should happen to that user's data (sessions, pins, access tokens)?
**A:** Soft removal via email anonymization. Replace the name part of the email with `deleted-(random string)@domain.com`. This preserves the user record and all associated data (no orphan records), but the user can no longer log in since their email no longer matches. Sessions are destroyed; pins and access tokens remain but become unusable.

**Q5:** When deleting the account, should ALL associated data be deleted immediately or should only the account be soft-deleted?
**A:** Soft delete account only. Mark account as deleted, block login, anonymize all user emails. Data stays intact for 30 days, then purge everything.

**Q6:** For the account deletion retention period — terms say deletion "at any time" but SoftDeletable uses 30 days. Which?
**A:** 30 days (consistent with existing workspace soft delete pattern). Update the terms of service to mention the 30-day retention period.

**Q7:** Should the account page include API tokens management?
**A:** No. API tokens are personal per user, not managed from the account screen.

**Q8:** Should there be a visual provided, or design following existing patterns?
**A:** Follow existing patterns — card-based layout like workspace edit, with sections.

**Q9:** Should we add a role to users for access control instead of using created_at ordering?
**A:** Yes. Add a `role` column to users with two values: `admin` and `member`. The first user created with the account (via `Account.create_with_user`) is always `admin`. Users joining via invitation are `member`. Only admins can access account management edit/delete features.

### Existing Code to Reference

**Similar Features Identified:**

- **Workspace edit form** — Path: `app/views/workspaces/edit.html.erb`, `app/views/workspaces/_form.html.erb` — Card wrapper with title/description, data-component form
- **Workspace deletion (soft delete)** — Path: `app/views/workspaces/deleted/` — 30-day retention warning alert pattern
- **SoftDeletable concern** — Path: `app/models/concerns/soft_deletable.rb` — Reusable for accounts
- **User dropdown (sidebar footer)** — Path: `app/views/application/components/sidebar/_nav_user.html.erb` — "Account" link currently points to `#`
- **Registration flow** — Path: `app/controllers/registrations_controller.rb` — How accounts are created with users
- **Authentication concern** — Path: `app/controllers/concerns/authentication.rb` — Login blocking will need account.deleted? check
- **Account model** — Path: `app/models/account.rb` — Minimal, needs SoftDeletable and invitation token support
- **Terms of service** — Path: `app/views/pages/terms.html.erb` — Section 7 needs 30-day retention mention
- **Seeds** — Path: `db/seeds.rb` — Demo user needs role: admin
- **User fixtures** — Path: `test/fixtures/users.yml` — Need role field, need member user for testing

## Visual Assets

### Files Provided

- `planning/visuals/sidebar-dropdown.png`: Screenshot of the sidebar user dropdown showing the "Account" link entry point

### Visual Insights

- The Account link is in the user dropdown in the sidebar footer
- The dropdown has a group structure: Account / Billing / Notifications, then separator, then Log out
- Only the "Account" link needs to be wired up in this feature
- Follows the existing dropdown menu pattern from maquina-components

## Requirements Summary

### Functional Requirements

1. **User role system** — Add `role` column (admin/member) to users, first user is admin, invited users are members
2. **Account name editing** — Form to update the account name (admin only)
3. **User list** — Display all active users with email, join date, and role badge
4. **User removal** — Admin can remove non-admin users by anonymizing their email (soft removal)
5. **Invitation links** — Generate a shareable invite URL with an encrypted token that expires in 7 days (admin only)
6. **User limit** — Maximum 5 active users per account, enforced on invitation acceptance
7. **Account deletion** — Soft delete with 30-day retention, all user emails anonymized, login blocked (admin only)
8. **Terms update** — Update terms of service section 7 to mention 30-day account data retention
9. **Sidebar link** — Wire up the "Account" link in the user dropdown to the account management page
10. **Role-based UI** — Admin sees full management page; member sees read-only view (account name, user list)

### Non-Functional Requirements

- Follows existing UI patterns (card sections, maquina-components, data-component attributes)
- Consistent with green oklch theme and font-display headings
- Responsive layout (mx-auto max-w-4xl container)
- Uses breadcrumbs for navigation context
- Toast notifications for success/error feedback
- Confirm dialog for destructive actions (user removal, account deletion)

### Reusability Opportunities

- SoftDeletable concern — can be included directly in Account model
- Workspace edit card pattern — same layout for account name form
- Deleted workspace alert pattern — same warning pattern for deletion confirmation
- Existing confirm dialog — `data: { turbo_confirm: "message" }` for destructive actions
- Registration flow — invitation acceptance can reuse the registration form with account pre-assignment

### Scope Boundaries

**In Scope:**
- User role system (admin/member)
- Account settings page (name editing, admin only)
- User list display (all users)
- User removal (email anonymization, admin only)
- Invitation link generation and display (admin only)
- Invitation acceptance (new user joins existing account as member)
- Account soft deletion with email anonymization (admin only)
- Terms of service update (30-day retention mention)
- Sidebar link wiring
- Seeds and fixtures updates
- Controller tests for all actions

**Out of Scope:**
- Billing section (placeholder stays as `#`)
- Notifications section (placeholder stays as `#`)
- API token management (personal per user)
- Account data export before deletion
- Account restoration after soft delete
- Promoting members to admin or demoting admins
- Invitation email sending (link is generated and displayed, user copies it)
- Permanent deletion job (30-day cleanup scheduled task)
- API endpoints for account management (HTML only for now)
- Transferring account ownership

### Technical Considerations

- **User roles**: Add `role` string column with default `"member"`. Validate inclusion in `%w[admin member]`. First user via `Account.create_with_user` gets `"admin"`.
- **Invitation token**: Use Rails MessageEncryptor to create encrypted tokens containing `{account_id, expires_at}`. Similar to password reset tokens.
- **Email anonymization**: Replace email `name@domain.com` with `deleted-<SecureRandom.hex(8)>@domain.com`. Must handle uniqueness.
- **Account deletion blocking**: Authentication concern needs to check if `Current.account.deleted?` and refuse login.
- **User limit enforcement**: Count non-anonymized users only. Check before invitation generation and acceptance.
- **Migration**: Add `role` to users (with data migration setting existing users to admin), add `deleted_at` to accounts.
- **Seeds**: Set demo user to admin role.
- **Fixtures**: Add role field, add member user to account one for removal tests.
