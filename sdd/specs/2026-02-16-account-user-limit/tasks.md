# Tasks: Account User Limit by Tenancy Mode

## Overview

- **Spec:** 2026-02-16-account-user-limit
- **Total Task Groups:** 3
- **Estimated Effort:** S (2-3 days)
- **Status:** Complete

---

## Task Groups

### Model & Logic Layer

#### Task Group 1: Tenancy-Aware User Limit
**Dependencies:** None

- [x] 1.0 Complete model logic changes
  - [x] 1.1 Write focused tests for tenancy-aware limit behavior
    - Test `at_user_limit?` returns `true` at 10 active users in multi-tenant mode
    - Test `at_user_limit?` returns `false` under 10 active users in multi-tenant mode
    - Test `at_user_limit?` returns `false` in single-tenant mode regardless of user count
    - Test `user_limit` returns `10` in multi-tenant mode
    - Test `user_limit` returns `nil` in single-tenant mode
  - [x] 1.2 Update `USER_LIMIT` constant from `5` to `10`
  - [x] 1.3 Make `at_user_limit?` tenancy-aware
    - Return `false` when `Rails.application.config.multi_tenant` is `false`
    - Check against `USER_LIMIT` when multi-tenant
  - [x] 1.4 Add `user_limit` method
    - Returns `USER_LIMIT` in multi-tenant mode
    - Returns `nil` in single-tenant mode
  - [x] 1.5 Update existing `at_user_limit?` tests to reflect new limit of 10
    - Adjust user creation count in "returns true at limit" test (8 additional users instead of 3)
  - [x] 1.6 Ensure model tests pass
    - Run ONLY `test/models/account_test.rb`

**Acceptance Criteria:**
- [x] All account model tests pass
- [x] `at_user_limit?` returns `false` in single-tenant regardless of user count
- [x] `at_user_limit?` checks against 10 in multi-tenant mode

---

### UI & Copy Updates

#### Task Group 2: Account Settings and Marketing Pages
**Dependencies:** Task Group 1

- [x] 2.0 Complete UI and copy updates
  - [x] 2.1 Write focused tests for tenancy-aware account settings display
    - Test account settings page shows "X of 10 users" in multi-tenant mode
    - Test account settings page shows "X active users" (no limit) in single-tenant mode
    - Test invitation limit-reached message displays with limit of 10
  - [x] 2.2 Update `_users.html.erb` partial
    - Use `multi_tenant?` helper to choose between `description` and `description_unlimited` I18n keys
    - Pass `account.user_limit` as `limit:` parameter in multi-tenant mode
  - [x] 2.3 Add I18n key `accounts.users.description_unlimited`
    - Value: "%{count} active users in this account."
    - Keep existing `accounts.users.description` unchanged (interpolates `%{limit}`)
  - [x] 2.4 Update `_invitations.html.erb` partial
    - Pass `account.user_limit` instead of `Account::USER_LIMIT` for the limit-reached message
  - [x] 2.5 Update marketing landing page copy
    - Change "Invite up to 5 users" to "Invite up to 10 users" in `_landing.html.erb`
  - [x] 2.6 Update marketing pricing page copy
    - Change "Up to 5 users per account" to "Up to 10 users per account" in Cloud tier
    - Change "Need more than 5 users?" to "Need more than 10 users?" in FAQ heading
    - Change FAQ structured data question from "Need more than 5 users?" to "Need more than 10 users?"
  - [x] 2.7 Ensure UI tests pass
    - Run `test/controllers/account_integration_test.rb` and `test/controllers/account/invitations_controller_test.rb`

**Acceptance Criteria:**
- [x] Account settings displays correct format per tenancy mode
- [x] Marketing pages reference 10 users (not 5)
- [x] Self-hosted "No user limits" unchanged on pricing page

---

### Testing & Verification

#### Task Group 3: Test Review & Gap Analysis
**Dependencies:** Task Groups 1-2

- [x] 3.0 Review and fill critical test gaps
  - [x] 3.1 Review all tests from Groups 1-2
    - Model tests: 4 new + 1 updated
    - Controller tests: 2 updated (user count adjustments)
    - Total new/updated: 7 tests
  - [x] 3.2 Identify critical gaps for this feature
    - Invitation acceptance flow with tenancy-aware limit
    - Controller-level limit check in `account/invitations_controller`
    - Controller-level limit check in `invitations_controller`
  - [x] 3.3 Add up to 5 strategic tests
    - Test invitation generation allowed at any count in single-tenant mode
    - Test invitation acceptance allowed at any count in single-tenant mode
    - Test invitation acceptance blocked at 10 users in multi-tenant mode
  - [x] 3.4 Run feature-specific tests
    - 41 tests, 119 assertions, 0 failures
  - [x] 3.5 Run full CI
    - 346 tests, 956 assertions, 0 failures

**Acceptance Criteria:**
- [x] All feature-specific tests pass
- [x] Full CI passes
- [x] Invitation flow respects tenancy-aware limits at both generation and acceptance

---

## Execution Order

1. Model & Logic Layer (Task Group 1)
2. UI & Copy Updates (Task Group 2)
3. Testing & Verification (Task Group 3)

---

## Progress Log

| Date | Task | Status | Notes |
|------|------|--------|-------|
| 2026-02-16 | Task Group 1 | ✅ Complete | Model changes + 24 model tests pass |
| 2026-02-16 | Task Group 2 | ✅ Complete | UI/copy + 8 controller tests pass |
| 2026-02-16 | Task Group 3 | ✅ Complete | 3 strategic tests added, 41 feature tests + full CI (346 tests) green |
