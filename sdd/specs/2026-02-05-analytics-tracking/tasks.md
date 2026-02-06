# Tasks: Analytics Tracking

## Overview

- **Spec:** 2026-02-05-analytics-tracking
- **Total Task Groups:** 5
- **Estimated Effort:** M (1 week)
- **Status:** Not Started

---

## Task Groups

### Database & Models Layer

#### Task Group 1: Analytics Models and Migrations
**Dependencies:** None

- [ ] 1.0 Complete analytics database and model layer
  - [ ] 1.1 Write 6 focused tests for analytics models
    - Test `Analytics::Event` validates presence of `event_type` and `created_at`
    - Test `Analytics::Event` stores and retrieves JSON `metadata`
    - Test `Analytics::ApiRequest` validates presence of `method`, `path`, `status`
    - Test `Analytics::ApiRequest` stores `duration_ms` as integer
    - Test `Analytics::IpAnonymizer.anonymize` zeroes last IPv4 octet
    - Test `Analytics::IpAnonymizer.anonymize` zeroes last 80 bits of IPv6
  - [ ] 1.2 Create migration for `analytics_events` table
    - Fields: `account_id` (integer, nullable), `user_id` (integer, nullable), `event_type` (string, not null), `resource_type` (string, nullable), `resource_id` (integer, nullable), `metadata` (json), `ip_address` (string, nullable), `user_agent` (string, nullable), `created_at` (datetime, not null)
    - Index: `[account_id, event_type, created_at]`
    - Index: `[resource_type, resource_id]`
    - Index: `[user_id, created_at]`
  - [ ] 1.3 Create migration for `analytics_api_requests` table
    - Fields: `account_id` (integer, nullable), `user_id` (integer, nullable), `access_token_id` (integer, nullable), `method` (string, not null), `path` (string, not null), `status` (integer, not null), `duration_ms` (integer), `ip_address` (string, nullable), `user_agent` (string, nullable), `created_at` (datetime, not null)
    - Index: `[account_id, created_at]`
    - Index: `[access_token_id, created_at]`
    - Index: `[path, method, created_at]`
  - [ ] 1.4 Create `Analytics::Event` model
    - Validates: `event_type` presence
    - Belongs to `account` (optional)
    - Belongs to `user` (optional)
    - Belongs to `resource` (polymorphic, optional)
    - Serialize `metadata` as JSON
  - [ ] 1.5 Create `Analytics::ApiRequest` model
    - Validates: `method`, `path`, `status` presence
    - Belongs to `account` (optional)
    - Belongs to `user` (optional)
    - Belongs to `access_token` (optional)
  - [ ] 1.6 Create `Analytics::IpAnonymizer` module
    - `anonymize(ip_string)` method using `IPAddr` from stdlib
    - IPv4: mask with `/24` (zeroes last octet)
    - IPv6: mask with `/48` (zeroes last 80 bits)
    - Returns `nil` for nil/blank, returns unchanged for unparseable
  - [ ] 1.7 Ensure model tests pass
    - Run ONLY tests from 1.1

**Acceptance Criteria:**
- [ ] All 6 tests from 1.1 pass
- [ ] Migrations run successfully (`bin/rails db:migrate`)
- [ ] Models validate correctly
- [ ] IP anonymizer handles IPv4, IPv6, nil, and invalid input

---

### Background Jobs Layer

#### Task Group 2: Analytics Jobs
**Dependencies:** Task Group 1

- [ ] 2.0 Complete analytics background jobs
  - [ ] 2.1 Write 4 focused tests for analytics jobs
    - Test `RecordEventJob` creates an `Analytics::Event` record with correct attributes
    - Test `RecordEventJob` silently discards invalid records (no exception raised)
    - Test `RecordApiRequestJob` creates an `Analytics::ApiRequest` record with correct attributes
    - Test `RecordApiRequestJob` silently discards invalid records (no exception raised)
  - [ ] 2.2 Create `Analytics::RecordEventJob`
    - Inherits from `ApplicationJob`
    - `perform(attributes)` creates `Analytics::Event.create!(attributes)`
    - Rescue `StandardError` and log warning (never raise)
  - [ ] 2.3 Create `Analytics::RecordApiRequestJob`
    - Inherits from `ApplicationJob`
    - `perform(attributes)` creates `Analytics::ApiRequest.create!(attributes)`
    - Rescue `StandardError` and log warning (never raise)
  - [ ] 2.4 Ensure job tests pass
    - Run ONLY tests from 2.1

**Acceptance Criteria:**
- [ ] All 4 tests from 2.1 pass
- [ ] Jobs create records when given valid attributes
- [ ] Jobs silently handle failures without raising

---

### Controller Concern Layer

#### Task Group 3: Analytics::Trackable Concern
**Dependencies:** Task Group 2

- [ ] 3.0 Complete analytics tracking concern
  - [ ] 3.1 Write 5 focused tests for the concern
    - Test `track_event` enqueues `RecordEventJob` with correct attributes
    - Test `track_event` anonymizes IP address
    - Test `track_event` includes metadata when provided
    - Test `track_api_request` enqueues `RecordApiRequestJob` with method, path, status, duration
    - Test `track_api_request` only fires for JSON requests
  - [ ] 3.2 Create `Analytics::Trackable` concern
    - `track_event(event_type, resource: nil, metadata: {})` private method
    - Assembles: `account_id`, `user_id`, `event_type`, `resource_type`, `resource_id`, `metadata`, anonymized `ip_address`, `user_agent`, `created_at`
    - Enqueues `Analytics::RecordEventJob.perform_later(attributes)`
    - `track_api_request` as private method
    - Reads `request.method`, `request.path`, `response.status`, calculates `duration_ms`
    - Assembles: `account_id`, `user_id`, `access_token_id`, `method`, `path`, `status`, `duration_ms`, anonymized `ip_address`, `user_agent`, `created_at`
    - Enqueues `Analytics::RecordApiRequestJob.perform_later(attributes)`
  - [ ] 3.3 Add `include Analytics::Trackable` to `ApplicationController`
  - [ ] 3.4 Add `after_action :track_api_request, if: :api_request?` to `ApplicationController`
  - [ ] 3.5 Store request start time via `before_action` for duration calculation
  - [ ] 3.6 Ensure concern tests pass
    - Run ONLY tests from 3.1

**Acceptance Criteria:**
- [ ] All 5 tests from 3.1 pass
- [ ] Concern properly assembles event and API request attributes
- [ ] IP addresses are anonymized before recording
- [ ] API request tracking fires only for JSON format requests

---

### Controller Instrumentation Layer

#### Task Group 4: Instrument Controllers with Tracking Calls
**Dependencies:** Task Group 3

- [ ] 4.0 Complete controller instrumentation
  - [ ] 4.1 Write 8 focused integration tests
    - Test `MemoriesController#show` (JSON) creates `memory.view` event
    - Test `MemoriesController#create` (JSON, success) creates `memory.create` event
    - Test `WorkspacesController#show` (HTML) creates `workspace.view` event
    - Test `Workspaces::ArchivesController#create` (JSON) creates `workspace.archive` event
    - Test `SearchController#index` (JSON) creates `search.query` event with metadata
    - Test `SessionsController#create` (success) creates `auth.sign_in` event
    - Test `SessionsController#create` (failure) creates `auth.sign_in_failed` event
    - Test `PinsController#create` creates `pin.create` event
  - [ ] 4.2 Instrument `MemoriesController`
    - `show`: `track_event("memory.view", resource: @memory)`
    - `create` (success): `track_event("memory.create", resource: @memory)`
    - `update` (success): `track_event("memory.update", resource: @memory)`
    - `destroy`: `track_event("memory.destroy", resource: @memory)`
  - [ ] 4.3 Instrument `Memories::VersionsController`
    - `create` (success): `track_event("version.create", resource: @version)`
  - [ ] 4.4 Instrument `WorkspacesController`
    - `show` (HTML, after redirect checks): `track_event("workspace.view", resource: @workspace)`
    - `create` (success): `track_event("workspace.create", resource: @workspace)`
    - `update` (success): `track_event("workspace.update", resource: @workspace)`
    - `destroy`: `track_event("workspace.delete", resource: @workspace)`
  - [ ] 4.5 Instrument `Workspaces::ArchivesController`
    - `create` (success): `track_event("workspace.archive", resource: @workspace)`
    - `destroy` (success): `track_event("workspace.unarchive", resource: @workspace)`
  - [ ] 4.6 Instrument `Workspaces::DeletedController`
    - `destroy`: `track_event("workspace.permanent_delete", resource: @workspace)`
  - [ ] 4.7 Instrument `SearchController`
    - `index` (after building scope): `track_event("search.query", metadata: {query: @query, results_count: @pagy.count, workspace_id: params[:workspace_id]})`
  - [ ] 4.8 Instrument `SessionsController`
    - `create` (success): `track_event("auth.sign_in")`
    - `create` (failure): `track_event("auth.sign_in_failed", metadata: {email_address: params[:email_address]})`
  - [ ] 4.9 Instrument `Authentication` concern
    - `authenticate_via_token` (when bearer token present but invalid): `track_event("auth.token_failed")`
  - [ ] 4.10 Instrument `PinsController`
    - `create`: `track_event("pin.create", resource: @pinnable)`
    - `destroy`: `track_event("pin.destroy", resource: @pinnable)`
  - [ ] 4.11 Ensure instrumentation tests pass
    - Run ONLY tests from 4.1

**Acceptance Criteria:**
- [ ] All 8 tests from 4.1 pass
- [ ] All controller actions emit the correct event type
- [ ] Events include the correct resource references
- [ ] Search events include query metadata
- [ ] Auth events fire for both success and failure

---

### Testing & Verification

#### Task Group 5: Test Review & Gap Analysis
**Dependencies:** Task Groups 1-4

- [ ] 5.0 Review and fill critical test gaps
  - [ ] 5.1 Review all tests from Groups 1-4
    - Model tests: 6 (from 1.1)
    - Job tests: 4 (from 2.1)
    - Concern tests: 5 (from 3.1)
    - Integration tests: 8 (from 4.1)
    - Total existing: 23
  - [ ] 5.2 Identify critical gaps
    - Focus on edge cases and integration points
    - Verify analytics doesn't break normal app flow
  - [ ] 5.3 Add up to 7 strategic tests
    - Test IP anonymizer with nil and unparseable input
    - Test API request tracking captures correct duration_ms
    - Test analytics job failure doesn't affect controller response
    - Test event tracking with no authenticated user (failed auth)
    - Test `MemoriesController#update` (JSON, success) creates `memory.update` event
    - Test `WorkspacesController#destroy` (JSON) creates both `workspace.delete` event and API request
    - Test existing test suite still passes (no regressions)
  - [ ] 5.4 Run full test suite
    - `bin/rails test`
    - Verify zero regressions
    - Expected analytics-specific tests: ~30

**Acceptance Criteria:**
- [ ] All analytics-specific tests pass
- [ ] Full test suite passes with zero regressions
- [ ] No more than 7 tests added in 5.3

---

## Execution Order

1. Database & Models Layer (Task Group 1)
2. Background Jobs Layer (Task Group 2)
3. Controller Concern Layer (Task Group 3)
4. Controller Instrumentation Layer (Task Group 4)
5. Testing & Verification (Task Group 5)

---

## Progress Log

| Date | Task | Status | Notes |
|------|------|--------|-------|
