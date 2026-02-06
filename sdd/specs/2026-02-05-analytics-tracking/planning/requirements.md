# Spec Requirements: Analytics Tracking

## Initial Description

Add basic analytics tracking to the application. Track how many times a memory is viewed or queried, how many API calls are made, track the user, time, and other relevant information. Store in separate analytics-namespaced tables. No UI exposure — database-only tracking for now.

## Requirements Discussion

### Questions & Answers

**Q1:** Should analytics events be recorded synchronously or asynchronously?
**A:** Asynchronous via Solid Queue background jobs. Zero impact on request latency.

**Q2:** What data retention strategy?
**A:** Keep everything. No automatic cleanup. Data grows indefinitely.

**Q3:** Should we track IP address and user agent on every event?
**A:** Track per event but anonymize what you can. Zero last octet for IPv4, last 80 bits for IPv6.

**Q4:** Any additional event types beyond the proposed set?
**A:** Include failed auth attempts for security monitoring. The rest of the proposed set (memory views, searches, creates/updates, version creates, workspace views/lifecycle, API requests, sign-ins, pins) is good.

### Existing Code to Reference

**Similar Features Identified:**
- **Session model** (`app/models/session.rb`) — already stores `ip_address` and `user_agent`
- **AccessToken** (`app/models/access_token.rb`) — tracks `last_used_at` via `touch_last_used!`
- **Authentication concern** (`app/controllers/concerns/authentication.rb`) — entry point for sign-in and token auth tracking
- **ApplicationJob** (`app/jobs/application_job.rb`) — base class for Solid Queue jobs
- **Current** (`app/models/current.rb`) — provides `Current.user`, `Current.session`, `Current.account`

## Visual Assets

No visual assets provided. This is a backend-only feature (database tracking, no UI).

## Requirements Summary

### Functional Requirements

- Track memory view events (show action, both HTML and API)
- Track search queries with result counts and optional workspace filter
- Track memory create/update events
- Track version create events
- Track workspace view events (show action)
- Track workspace lifecycle events (archive, unarchive, soft delete, permanent delete, restore)
- Track API requests with endpoint, method, token, response status, and latency
- Track successful sign-in events
- Track failed authentication attempts (login failures, invalid API tokens)
- Track pin/unpin activity
- Anonymize IP addresses (zero last octet IPv4 / last 80 bits IPv6)
- Record events asynchronously via Solid Queue

### Non-Functional Requirements

- Zero impact on request latency (async recording)
- Events stored in dedicated analytics tables (not mixed with domain data)
- Models namespaced under `Analytics::`
- Keep all data indefinitely (no retention policy)

### Scope Boundaries

**In Scope:**
- `Analytics::Event` model for user activity events
- `Analytics::ApiRequest` model for API traffic logging
- `Analytics::RecordEventJob` background job
- `Analytics::RecordApiRequestJob` background job
- Controller concern `Analytics::Trackable` for instrumentation
- IP anonymization utility
- Database migrations with proper indexes
- Model tests and controller integration tests

**Out of Scope:**
- UI dashboards or analytics views
- Data aggregation or rollups
- Export functionality
- Admin API endpoints for querying analytics
- Real-time analytics or WebSocket streaming
- Third-party analytics integration
