# Specification: Account User Limit by Tenancy Mode

## Goal

Make the account user limit tenancy-aware: 10 users maximum in multi-tenant mode, unlimited in single-tenant mode. Update all UI surfaces (account settings, marketing pages) to reflect the correct limit for the active mode.

## User Stories

- As an account admin in multi-tenant mode, I want the user limit increased to 10 so that larger teams can collaborate on shared knowledge.
- As a self-hosted operator in single-tenant mode, I want no user limit so that my entire organization can use the application without artificial constraints.
- As a visitor on the marketing site, I want pricing and feature descriptions to accurately reflect the current limits so that I can make an informed decision.

## Specific Requirements

**Account Model Changes**
- Change `USER_LIMIT` constant from `5` to `10`
- Make `at_user_limit?` tenancy-aware: check `Rails.application.config.multi_tenant`; return `false` when single-tenant, check against `USER_LIMIT` when multi-tenant
- Add `user_limit` method that returns `USER_LIMIT` in multi-tenant mode and `nil` in single-tenant mode (used by views to decide display format)

**Account Settings — Users Card**
- Multi-tenant: keep current format — "X of 10 users in this account."
- Single-tenant: show "X active users in this account." (no denominator)
- The `_users.html.erb` partial should use `multi_tenant?` helper to choose the appropriate I18n key
- Add a new I18n key `accounts.users.description_unlimited` for single-tenant: "%{count} active users in this account."

**Account Settings — Invitations Card**
- The limit-reached message already interpolates `%{limit}` — no change needed beyond the constant bump from 5 to 10
- `at_user_limit?` returning `false` in single-tenant means the limit-reached block never renders, which is correct

**Marketing Landing Page**
- Change line 378 in `_landing.html.erb` from "Invite up to 5 users" to "Invite up to 10 users"

**Marketing Pricing Page**
- Change Cloud tier feature from "Up to 5 users per account" to "Up to 10 users per account" (line 76)
- Change FAQ heading from "Need more than 5 users?" to "Need more than 10 users?" (line 99)
- Change FAQ structured data question from "Need more than 5 users?" to "Need more than 10 users?" (line 12)
- Change FAQ answer text to reference "higher limits" (keep current wording, it already says "higher limits")
- Self-hosted tier "No user limits" stays unchanged

**I18n Updates**
- `accounts.users.description`: keep as "%{count} of %{limit} users in this account." (limit will now be 10)
- Add `accounts.users.description_unlimited`: "%{count} active users in this account."
- `accounts.invitations.limit_reached`: keep as-is (already interpolates `%{limit}`, will get 10)

**Test Updates**
- Update `at_user_limit?` true-at-limit test: needs 8 additional users (not 3) to reach limit of 10 in multi-tenant mode
- Add test: `at_user_limit?` returns `false` in single-tenant mode regardless of user count
- Add test: `user_limit` returns `10` in multi-tenant, `nil` in single-tenant

## Existing Code to Leverage

**Account model** (`app/models/account.rb`)
- `USER_LIMIT = 5` — bump to 10
- `at_user_limit?` — add tenancy check
- `Rails.application.config.multi_tenant` — already used app-wide for tenancy decisions

**Views**
- `app/views/accounts/_users.html.erb:6` — passes `Account::USER_LIMIT` to I18n
- `app/views/accounts/_invitations.html.erb:9-11` — checks `at_user_limit?`, shows limit message
- `app/views/home/_landing.html.erb:378` — "Invite up to 5 users" copy
- `app/views/pages/pricing.html.erb:12,53,76,99` — pricing page references to 5 users

**I18n** (`config/locales/views/en.yml`)
- `accounts.users.description` — existing key with `%{count}` and `%{limit}`
- `accounts.invitations.limit_reached` — existing key with `%{limit}`

**Tests**
- `test/models/account_test.rb:57-73` — existing `at_user_limit?` tests
- `test/controllers/account/invitations_controller_test.rb:31` — asserts `at_user_limit?`
- `test/controllers/account_integration_test.rb:46` — asserts `at_user_limit?`
- Tenancy stub pattern: `Rails.application.config.stub(:multi_tenant, false)` used in other tests

## Out of Scope

- Per-account configurable user limits (all accounts share the same constant)
- Admin UI to change limits at runtime
- API endpoint changes (limit is internal, not exposed)
- Changing invitation mechanics (tokens, expiry, acceptance flow)
- Pricing tier restructuring or adding new tiers
- Adding a "contact sales" form for enterprise needs
