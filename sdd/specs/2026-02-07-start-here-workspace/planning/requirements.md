# Spec Requirements: Start Here Workspace

## Initial Description

Seed a "Start Here" workspace with onboarding memories when a new account is created. The workspace contains five memories that serve as both a manual and the starting point for new users:

1. **Why recuerd0** — what it does and how it helps (pinned)
2. **Quick Manual** — account settings, user settings, invitations, access tokens, data export
3. **The API** — REST API overview with authentication and endpoints
4. **The CLI** — command-line interface usage
5. **The Agent** — AI agent integration

## Requirements Discussion

### Questions & Answers

**Q1:** Where should the seeding logic live?
**A:** In the Account model as an `after_create` callback or as a method called from `Account.create_with_user`. The seeding should be automatic — no user action required.

**Q2:** Should the workspace be deletable/archivable by the user?
**A:** Yes, treat it like any normal workspace. Users should have full control.

**Q3:** What format should the memory content be in?
**A:** Markdown, consistent with how all memory content is stored (via Commonmarker rendering).

**Q4:** Should the "Why recuerd0" memory be pinned for the user?
**A:** Yes, pin it for the admin user who created the account.

**Q5:** Should the seed content be translatable (I18n)?
**A:** No, English-only for now. Content is stored as markdown strings.

**Q6:** What happens if account creation fails after workspace creation?
**A:** The entire operation is in a transaction via `Account.create_with_user`, so the workspace creation should be wrapped inside the same transaction or executed as an after_commit callback.

## Visual Assets

No visual assets provided. This is a backend-only feature — no UI changes.

## Requirements Summary

### Functional Requirements

- When a new account is created, automatically create a "Start Here" workspace
- Create 5 memories with markdown content in that workspace
- Pin the "Why recuerd0" memory for the admin user
- Content should reflect the product's actual capabilities as documented in docs/ and marketing pages
- Source field should be set to "system" for all seeded memories

### Non-Functional Requirements

- Seed operation must be idempotent for the development seeds (db/seeds.rb)
- Production seeding via after_create callback must not slow down registration noticeably
- Memory content should follow the brand voice: direct, technical, no hype

### Reusability Opportunities

- `Memory.create_with_content` already handles memory + content creation in a transaction
- `Pin.toggle_pin_for!` or `pin!` handles pinning
- The existing `Account.create_with_user` transaction wraps account + user creation

### Scope Boundaries

**In Scope:**
- Account model method to seed the "Start Here" workspace
- 5 memories with meaningful markdown content
- Pinning "Why recuerd0" for the admin user
- after_create callback on Account
- Tests for the seeding behavior

**Out of Scope:**
- I18n/translations of seed content
- UI changes
- Updating existing accounts with the new workspace
- Making the workspace read-only or special in any way

### Technical Considerations

- Use `after_create` callback on Account model to trigger seeding
- The callback receives the account; the first user (admin) is created in the same transaction
- Need to pass the user to the seeding method for pinning
- Keep memory content concise but useful — these are onboarding docs, not full reference
