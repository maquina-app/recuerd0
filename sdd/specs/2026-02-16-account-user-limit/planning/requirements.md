# Spec Requirements: Account User Limit by Tenancy Mode

## Initial Description

Change the account user limit from a fixed 5 to be tenancy-aware: 10 users max in multi-tenant mode, unlimited in single-tenant mode. Update marketing pages and account settings UI to reflect the new limits.

## Requirements Discussion

### Questions & Answers

**Q1:** For single-tenant mode (no limit), should `at_user_limit?` always return `false`, or should we remove the limit check entirely from the invitation flow?
**A:** Always return `false`. Minimal code changes, same flow everywhere.

**Q2:** The pricing page currently shows "No user limits" for self-hosted and "Up to 5 users per account" for hosted. Should self-hosted keep saying "No user limits" and hosted change to "Up to 10 users"?
**A:** Yes, that mapping. Self-hosted: "No user limits", Hosted: "Up to 10 users per account".

**Q3:** The landing page mentions "Invite up to 5 users with signed tokens." Should this just become "Invite up to 10 users" or should it be tenancy-aware (dynamic)?
**A:** Static "10 users" — the landing page is only shown in multi-tenant mode anyway.

**Q4:** The account settings page shows "X of 5 users". In single-tenant (unlimited), what should it display?
**A:** Just show count — "X active users" with no limit denominator in single-tenant mode.

### Existing Code to Reference

**Similar Features Identified:**
- **Account model** — `app/models/account.rb` — `USER_LIMIT = 5` constant, `at_user_limit?` method
- **Invitation controllers** — `app/controllers/account/invitations_controller.rb`, `app/controllers/invitations_controller.rb` — both check `at_user_limit?`
- **Account settings views** — `app/views/accounts/_users.html.erb` (shows "X of 5"), `app/views/accounts/_invitations.html.erb` (shows limit reached message)
- **I18n strings** — `config/locales/views/en.yml` (accounts.users.description, accounts.invitations.limit_reached)
- **Marketing landing** — `app/views/home/_landing.html.erb:378` — "Invite up to 5 users"
- **Marketing pricing** — `app/views/pages/pricing.html.erb` — "Up to 5 users per account", "No user limits"
- **Tests** — `test/models/account_test.rb` (at_user_limit? tests), `test/controllers/account_integration_test.rb`, `test/controllers/account/invitations_controller_test.rb`

## Visual Assets

No visual assets provided. Changes are text/logic updates to existing UI.

## Requirements Summary

### Functional Requirements

- Change `USER_LIMIT` from 5 to 10
- Make `at_user_limit?` tenancy-aware: returns `false` always in single-tenant mode, checks against limit in multi-tenant mode
- Update account settings users card: show "X active users" (no denominator) in single-tenant, "X of 10 users" in multi-tenant
- Update invitation limit-reached message to reference 10 instead of 5
- Update landing page copy: "Invite up to 10 users with signed tokens"
- Update pricing page copy: hosted tier shows "Up to 10 users per account" (self-hosted keeps "No user limits")

### Non-Functional Requirements

- No new gems or dependencies
- Existing test coverage must be updated to reflect new limit and tenancy-aware behavior

### Reusability Opportunities

- `multi_tenant?` helper already available in controllers and views
- `Rails.application.config.multi_tenant` accessible from models

### Scope Boundaries

**In Scope:**
- Account model limit constant and `at_user_limit?` logic
- I18n strings referencing user limits
- Account settings UI (users card, invitations card)
- Marketing landing page copy
- Marketing pricing page copy
- Test updates

**Out of Scope:**
- Changing the invitation system mechanics (tokens, expiry)
- Adding per-account configurable limits
- Admin UI to change limits
- API endpoint changes (limit is internal, not exposed via API)

### Technical Considerations

- `multi_tenant?` helper is available in controllers and views but not directly in models — the model will need to check `Rails.application.config.multi_tenant`
- The `at_user_limit?` method is called from two controllers and two view partials
- I18n strings use `%{limit}` interpolation — the users description string may need a new variant for single-tenant (no limit display)
