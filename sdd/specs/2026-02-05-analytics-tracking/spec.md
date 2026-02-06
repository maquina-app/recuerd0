# Specification: Analytics Tracking

## Goal

Add backend analytics tracking to Recuerd0 so that user activity (memory views, searches, content changes, workspace interactions, auth events, pin activity) and API traffic are recorded asynchronously to dedicated database tables for later analysis.

## User Stories

- As an admin, I want memory view and search activity tracked so that I can understand which content is most accessed
- As an admin, I want API request metrics tracked so that I can monitor programmatic usage patterns and detect anomalies
- As an admin, I want authentication events (successes and failures) tracked so that I can identify security concerns

## Specific Requirements

**Analytics::Event Model**
- Stores general-purpose user activity events
- Fields: `account_id`, `user_id` (nullable for failed auth), `event_type`, `resource_type` (nullable), `resource_id` (nullable), `metadata` (JSON), `ip_address` (anonymized), `user_agent`, `created_at`
- `event_type` is a string enum: `memory.view`, `memory.create`, `memory.update`, `memory.destroy`, `version.create`, `workspace.view`, `workspace.create`, `workspace.update`, `workspace.archive`, `workspace.unarchive`, `workspace.delete`, `workspace.restore`, `workspace.permanent_delete`, `search.query`, `auth.sign_in`, `auth.sign_in_failed`, `auth.token_failed`, `pin.create`, `pin.destroy`
- Polymorphic `resource_type`/`resource_id` references the target record (Memory, Workspace, etc.)
- `metadata` stores event-specific data as JSON (e.g., search query, result count, workspace_id filter)
- Index on `[account_id, event_type, created_at]` for filtered time-range queries
- Index on `[resource_type, resource_id]` for per-resource lookups
- Index on `[user_id, created_at]` for per-user activity feeds

**Analytics::ApiRequest Model**
- Dedicated table for API traffic (higher volume, different query patterns)
- Fields: `account_id` (nullable for failed auth), `user_id` (nullable), `access_token_id` (nullable), `method`, `path`, `status`, `duration_ms`, `ip_address` (anonymized), `user_agent`, `created_at`
- `method` is the HTTP verb (GET, POST, PATCH, DELETE)
- `path` is the request path without query string
- `status` is the HTTP response status code (integer)
- `duration_ms` is request processing time in milliseconds (integer)
- Index on `[account_id, created_at]` for time-range queries
- Index on `[access_token_id, created_at]` for per-token usage
- Index on `[path, method, created_at]` for endpoint-level metrics

**IP Anonymization**
- Module `Analytics::IpAnonymizer` with a single `anonymize(ip_string)` method
- IPv4: zero the last octet (e.g., `192.168.1.42` → `192.168.1.0`)
- IPv6: zero the last 80 bits (e.g., `2001:db8::1` → `2001:db8::`)
- Returns `nil` for nil/blank input
- Returns input unchanged if not parseable as IP

**Background Jobs**
- `Analytics::RecordEventJob` — receives event attributes hash, creates `Analytics::Event` record
- `Analytics::RecordApiRequestJob` — receives request attributes hash, creates `Analytics::ApiRequest` record
- Both use `perform_later` for async execution
- Both silently discard failures (analytics should never break the app)

**Controller Concern: Analytics::Trackable**
- Provides `track_event(event_type, resource: nil, metadata: {})` method
- Automatically captures `Current.account&.id`, `Current.user&.id`, anonymized `request.remote_ip`, `request.user_agent`
- Enqueues `Analytics::RecordEventJob` with the assembled attributes
- Provides `track_api_request` as an `after_action` callback for JSON requests
- Uses `request.method`, `request.path`, `response.status`, and calculates `duration_ms` from `process_action` timing

**Controller Instrumentation Points**
- `MemoriesController#show` → `memory.view` (both HTML and JSON)
- `MemoriesController#create` (success only) → `memory.create`
- `MemoriesController#update` (success only) → `memory.update`
- `MemoriesController#destroy` → `memory.destroy`
- `Memories::VersionsController#create` (success only) → `version.create`
- `WorkspacesController#show` (HTML only, after redirect checks) → `workspace.view`
- `WorkspacesController#create` (success only) → `workspace.create`
- `WorkspacesController#update` (success only) → `workspace.update`
- `WorkspacesController#destroy` → `workspace.delete`
- `Workspaces::ArchivesController#create` (success only) → `workspace.archive`
- `Workspaces::ArchivesController#destroy` (success only) → `workspace.unarchive`
- `Workspaces::DeletedController#destroy` → `workspace.permanent_delete`
- `SearchController#index` (after building scope, both HTML and JSON) → `search.query` with metadata: `{query:, results_count:, workspace_id:}`
- `SessionsController#create` (success) → `auth.sign_in`
- `SessionsController#create` (failure) → `auth.sign_in_failed` with metadata: `{email_address:}`
- `Authentication#authenticate_via_token` (failure, when bearer token present but invalid) → `auth.token_failed`
- `PinsController#create` → `pin.create`
- `PinsController#destroy` → `pin.destroy`
- API requests: `after_action :track_api_request, if: :api_request?` in `ApplicationController`

## Existing Code to Leverage

**Current (app/models/current.rb)**
- Provides `Current.user`, `Current.session`, `Current.account` for request context
- Analytics tracking methods will read from these

**Authentication concern (app/controllers/concerns/authentication.rb)**
- `authenticate_via_token` is the hook point for `auth.token_failed` events
- `start_new_session_for` is called after successful login

**ApplicationJob (app/jobs/application_job.rb)**
- Base class for Solid Queue jobs
- Analytics jobs inherit from this

**ApplicationController (app/controllers/application_controller.rb)**
- Already includes `Authentication`, `ApiHelpers`, `Pagy::Backend`
- `api_request?` helper already defined
- Natural place to add `include Analytics::Trackable` and the `after_action` for API tracking

## Out of Scope

- UI dashboards or admin analytics views
- Data aggregation, rollups, or summary tables
- Export or download functionality
- REST API endpoints for querying analytics data
- Real-time analytics streaming
- Analytics for registration, password reset, or invitation flows
- Page-level timing (frontend performance metrics)
- Geolocation from IP addresses
