# Tasks: Account Data Export

## Task Group 1: Database & Model (Foundation)

### Tasks
- [ ] 1.1 Add `rubyzip` gem to Gemfile as explicit dependency and run `bundle install`
- [ ] 1.2 Run `bin/rails active_storage:install` if Active Storage migrations don't exist yet, then `bin/rails db:migrate`
- [ ] 1.3 Create migration for `account_exports` table (account_id, user_id, status, completed_at, expires_at, error_message)
- [ ] 1.4 Create `AccountExport` model with associations, validations, scopes, and constants
- [ ] 1.5 Create test fixtures for `account_exports`
- [ ] 1.6 Write model tests

### Tests (6)
- [ ] T1.1 `exports_this_month` scope returns only exports from current calendar month
- [ ] T1.2 `expired?` returns true when `expires_at` is in the past
- [ ] T1.3 `downloadable?` returns true only when completed, not expired, and archive attached
- [ ] T1.4 validates presence of account and user
- [ ] T1.5 validates status inclusion in allowed values
- [ ] T1.6 `MONTHLY_LIMIT` constant equals 2

### Acceptance Criteria
- AccountExport model created with all columns, associations, and scopes
- Fixtures available for testing
- All 6 tests pass

---

## Task Group 2: Export Job (Core Logic)

### Tasks
- [ ] 2.1 Create `Account::ExportJob` with temp directory setup and cleanup
- [ ] 2.2 Implement workspace folder creation with `_workspace.yml` metadata
- [ ] 2.3 Implement memory export as markdown with YAML frontmatter
- [ ] 2.4 Implement filename sanitization helper (private method)
- [ ] 2.5 Implement ZIP creation and Active Storage upload
- [ ] 2.6 Implement status transitions (pending → processing → completed/failed)
- [ ] 2.7 Send completion email after successful export
- [ ] 2.8 Write job tests

### Tests (5)
- [ ] T2.1 Job creates ZIP with correct folder structure (workspace folders, memory files)
- [ ] T2.2 Memory files contain correct YAML frontmatter (title, tags, source, dates)
- [ ] T2.3 Job updates export status to `completed` and sets `completed_at`/`expires_at`
- [ ] T2.4 Job sets status to `failed` with error message on exception
- [ ] T2.5 Filename sanitization handles special characters, duplicates, and empty titles

### Acceptance Criteria
- Job creates valid ZIP with workspace/memory structure
- Latest version only exported (not all versions)
- Soft-deleted workspaces excluded
- Temp directory always cleaned up (even on failure)
- Export status correctly transitions through states

---

## Task Group 3: Cleanup Job

### Tasks
- [ ] 3.1 Create `Account::ExportCleanupJob`
- [ ] 3.2 Configure recurring schedule in `config/recurring.yml`
- [ ] 3.3 Write cleanup job tests

### Tests (3)
- [ ] T3.1 Cleanup destroys expired exports and purges attachments
- [ ] T3.2 Cleanup destroys failed exports older than 1 day
- [ ] T3.3 Cleanup does not touch active (non-expired) exports

### Acceptance Criteria
- Expired exports purged (Active Storage blob + record)
- Failed exports cleaned up after 1 day
- Recurring job scheduled daily

---

## Task Group 4: Mailer

### Tasks
- [ ] 4.1 Create `AccountExportMailer` with `started` and `completed` actions
- [ ] 4.2 Create mailer view templates (`started.html.erb`, `completed.html.erb`)
- [ ] 4.3 Add I18n keys for mailer subjects
- [ ] 4.4 Write mailer tests

### Tests (4)
- [ ] T4.1 `started` email sent to requesting user with correct subject
- [ ] T4.2 `completed` email contains download link
- [ ] T4.3 Both emails inherit logo attachment from ApplicationMailer
- [ ] T4.4 Mailer uses I18n for subjects

### Acceptance Criteria
- Both emails render correctly with app styling
- Download link in completed email points to correct URL
- Subjects use I18n

---

## Task Group 5: Controller & Routes

### Tasks
- [ ] 5.1 Add routes: `resources :exports, only: %i[create show], controller: "account/exports"` nested under account
- [ ] 5.2 Create `Account::ExportsController` with `create` and `show` actions
- [ ] 5.3 Add I18n flash messages for controller actions
- [ ] 5.4 Write controller tests

### Tests (6)
- [ ] T5.1 `create` enqueues export job and redirects with notice (admin)
- [ ] T5.2 `create` rejects when monthly limit exceeded (returns alert)
- [ ] T5.3 `create` rejects non-admin users (redirects)
- [ ] T5.4 `show` redirects to Active Storage blob for downloadable export
- [ ] T5.5 `show` redirects to account_path with alert for expired export
- [ ] T5.6 `show` requires authentication

### Acceptance Criteria
- Admin can request export within monthly limit
- Non-admins cannot request exports
- Download serves Active Storage blob
- Expired exports return helpful error

---

## Task Group 6: UI (Account Page)

### Tasks
- [ ] 6.1 Create `accounts/_data_export.html.erb` partial with card component
- [ ] 6.2 Add export card to account show view (admin column, before danger zone)
- [ ] 6.3 Add I18n keys for all view text
- [ ] 6.4 Handle states: limit reached, export in progress, downloadable export, no exports

### Tests (4)
- [ ] T6.1 Admin sees export card on account page
- [ ] T6.2 Export button disabled when monthly limit reached
- [ ] T6.3 Download link visible when completed export exists
- [ ] T6.4 Member does not see export card

### Acceptance Criteria
- Card renders with correct states (available, processing, limit reached, downloadable)
- Follows maquina-components card pattern
- All text uses I18n keys
- Confirm dialog on export request

---

## Summary

| Group | Tasks | Tests |
|-------|-------|-------|
| 1. Database & Model | 6 | 6 |
| 2. Export Job | 8 | 5 |
| 3. Cleanup Job | 3 | 3 |
| 4. Mailer | 4 | 4 |
| 5. Controller & Routes | 4 | 6 |
| 6. UI | 4 | 4 |
| **Total** | **29** | **28** |
