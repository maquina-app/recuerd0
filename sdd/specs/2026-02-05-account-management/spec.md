# Specification: Account Management

## Goal

Provide a centralized account management page where account admins can edit account details, manage users, invite new members via shareable links, remove users, and delete the account with a 30-day soft-delete retention period. Introduces a user role system (admin/member) to control access.

## User Stories

- As an account admin, I want to manage my account settings and users from a single page so that I have full control over my account.
- As an account admin, I want to invite new users by generating a shareable link so that they can join my account without manual provisioning.
- As an account admin, I want to delete my account with a clear warning about the 30-day retention period so that I understand the consequences before proceeding.

## Specific Requirements

**1. User Role System**
- Add `role` column to users table (string, not null, default: `"member"`)
- Two roles: `admin` and `member`
- Validate inclusion in `User::ROLES = %w[admin member]`
- The first user created via `Account.create_with_user` is always `admin`
- Users joining via invitation link are always `member`
- `User#admin?` and `User#member?` convenience methods
- Only admins can access the account management page
- Update seeds: set the demo user as `admin`
- Update fixtures: add `role` field to existing users

**2. Account Name Editing**
- Display account name in an editable form within a card section
- Follow the workspace edit form pattern (card/header + card/content + data-component form)
- Validate presence and max length (100 characters)
- Show toast notification on successful update
- Show inline validation errors on failure
- Only admins can update

**3. User List**
- Display all non-anonymized users in the account in a list section
- Show: email address, join date (time_ago_in_words), role badge (admin/member)
- Order by `created_at ASC`
- No ordering controls needed

**4. User Removal**
- Account admin can remove any non-admin user
- Removal anonymizes the email: replace `name@domain.com` with `deleted-<SecureRandom.hex(8)>@domain.com`
- Requires turbo_confirm dialog: "This will permanently remove this user's access to the account. They will not be able to log in again."
- The user record is preserved (associations remain intact, no orphan records)
- All active sessions for the removed user are destroyed
- Toast notification on success
- Admin cannot remove themselves (no self-removal button shown)
- Members cannot remove anyone

**5. Invitation Link Generation**
- Button to generate a new invitation link
- Uses Rails MessageEncryptor to create an encrypted token containing `{account_id, expires_at}`
- Token expires in 7 days
- Display the generated URL in a copyable text field
- Show remaining slots: "X of 5 users" indicator
- Disable generation when account is at 5-user limit
- Only one active invitation link at a time (generating new one invalidates previous)
- Only admins can generate invitations

**6. Invitation Acceptance**
- New route: `GET /invitations/:token` to show registration form pre-linked to account
- Modified registration form that accepts the invitation token
- On registration, user is created under the invited account with `role: "member"`
- Validate: token not expired, account exists, account not deleted, user count < 5
- Show error page for invalid/expired tokens
- After successful registration, redirect to workspaces with welcome toast

**7. User Limit**
- Maximum 5 users per account (constant `Account::USER_LIMIT = 5`)
- Enforced on invitation acceptance (registration)
- Enforced on invitation link generation (UI disables when at limit)
- Display current count on the account page
- Count excludes anonymized users (`deleted-*` pattern)

**8. Account Deletion**
- Destructive action at the bottom of the account page
- Requires turbo_confirm dialog with warning: "This will permanently delete your account and all data after 30 days. All users will lose access immediately. This action cannot be undone."
- On deletion: soft-delete account (set `deleted_at`), anonymize ALL user emails in the account, destroy ALL active sessions
- After deletion, redirect to root path (landing page)
- Authentication concern blocks login for users whose account is deleted
- Display destructive alert with warning variant and trash icon
- Only admins can delete the account

**9. Account Deletion Login Blocking**
- Authentication concern checks `Current.account&.deleted?` after resolving user
- If account is deleted, destroy the session and redirect to login with "Account has been deleted" flash
- Bearer token auth also checks account deletion status

**10. Sidebar Link & Access Control**
- Wire the "Account" link in the user dropdown to `account_path` (singular resource route)
- The link is visible to all users but the page enforces admin-only access
- Members who navigate to the account page see a read-only view (account name, user list) — no edit form, no invitations, no danger zone
- Alternatively: redirect members away with a flash message

**11. Terms of Service Update**
- Update section 7 (Termination) to mention: "After account closure, your data will be retained for 30 days before permanent deletion."
- Keep existing language about export period

## Visual Design

No high-fidelity mockups provided. Design follows existing UI patterns:

**Page layout:**
- `mx-auto max-w-4xl` container
- Multiple card sections stacked vertically with `space-y-6`
- Breadcrumbs: "Account" (no parent — top-level page)

**Section 1: Account Details (card)**
- card/header: "Account Settings" title, "Manage your account name and details" description
- card/content: form with name input, submit button
- Admin only: form is editable. Members: read-only display of account name

**Section 2: Users (card)**
- card/header: "Users" title, "X of 5 users in this account" description
- card/content: list of users (avatar, email, date, role badge, remove button)
- Each user row: `flex items-center gap-4 py-3` with separator between rows
- Role badges: admin = `:default` badge, member = no badge (or `:secondary`)
- Remove button only shown for admins, and only on non-admin users

**Section 3: Invitations (card) — admin only**
- card/header: "Invite Users" title, "Generate a shareable link for new members" description
- card/content: Generate button + copyable URL display (if link exists)
- Show remaining slots, disable when at limit
- Show "Expires in 7 days" text beneath URL

**Section 4: Danger Zone (card with destructive border) — admin only**
- card/header: "Delete Account" in destructive text color
- card/content: Warning alert (variant: :warning, icon: :alert_triangle): "Deleting your account will permanently remove all data after 30 days..."
- Delete button (variant: destructive, turbo_confirm with full warning text)

## Existing Code to Leverage

**SoftDeletable concern**
- Already implements `soft_delete`, `restore`, `deleted?`, `days_until_permanent_deletion`
- Include in Account model, add `deleted_at` column via migration
- Path: `app/models/concerns/soft_deletable.rb`

**Workspace edit form pattern**
- Card wrapper with card/header (title + description) and card/content (form)
- data-component="form" for grid gap-6 layout
- data-form-part="group" for field groups
- Path: `app/views/workspaces/edit.html.erb`, `app/views/workspaces/_form.html.erb`

**Deleted workspace alert pattern**
- Warning alert with trash icon showing days until permanent deletion
- Path: `app/views/workspaces/deleted/show.html.erb`

**Authentication concern**
- `require_authentication` before_action, `resume_session`, token auth
- Path: `app/controllers/concerns/authentication.rb`

**Registration controller**
- `Account.create_with_user` for new accounts
- Path: `app/controllers/registrations_controller.rb`

## Out of Scope

- Billing management (sidebar link stays as placeholder)
- Notifications management (sidebar link stays as placeholder)
- API token management (personal per user, separate feature)
- Account data export before deletion
- Account restoration after soft delete (future admin feature)
- Promoting members to admin or demoting admins
- Invitation email sending (URL is displayed for manual sharing)
- Permanent deletion background job (30-day cleanup task)
- API endpoints for account management (HTML only for now)
- Transferring account ownership
