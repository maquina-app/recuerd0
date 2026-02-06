# Spec: Account Data Export

## Goal
Allow account admins to download a complete ZIP backup of their account data (workspaces and memories as a file system). Limited to 2 exports per calendar month. Asynchronous processing via Solid Queue with email notifications for start and completion.

## User Stories

1. As an **admin**, I want to request a data export from the account page so I can have a backup of all my workspaces and memories.
2. As an **admin**, I receive an email when my export starts and another when it's ready to download.
3. As an **admin**, I can download my export via an authenticated, time-limited link.
4. As the **system**, expired backups are automatically cleaned up to free storage.

## Requirements

### R1: Data Export Model

**New model: `AccountExport`** — tracks export requests and stores the ZIP file.

| Column | Type | Notes |
|--------|------|-------|
| `account_id` | integer | FK to accounts, not null |
| `user_id` | integer | FK to users (who requested it), not null |
| `status` | string | `pending`, `processing`, `completed`, `failed` |
| `completed_at` | datetime | When the export finished |
| `expires_at` | datetime | 5 days after completion |
| `error_message` | text | Failure reason (if failed) |
| `created_at` | datetime | |
| `updated_at` | datetime | |

- `has_one_attached :archive` for the ZIP file (Active Storage)
- Scoped to account: `belongs_to :account`
- `belongs_to :user` (the admin who requested)
- Index on `account_id` and `expires_at`
- Scope `exports_this_month` to count exports in current calendar month per account
- Constant `MONTHLY_LIMIT = 2`
- Constant `EXPIRY_DAYS = 5`
- Method `expired?` returns `expires_at.present? && expires_at < Time.current`
- Method `downloadable?` returns `completed? && !expired? && archive.attached?`

### R2: Export Request (Controller)

**New controller: `Account::ExportsController`** — nested under account resource.

- `create` action (POST):
  - Requires authentication + admin authorization (`AdminAuthorizable`)
  - Checks monthly limit (2 per calendar month per account)
  - Creates `AccountExport` record with `status: "pending"`
  - Enqueues `Account::ExportJob`
  - Sends `AccountExportMailer.started` email
  - Redirects to `account_path` with notice toast
  - If limit exceeded: redirects with alert toast

- `show` action (GET):
  - Requires authentication + admin authorization (`AdminAuthorizable`)
  - Finds export by ID, scoped to `Current.account`
  - Validates export is `downloadable?`
  - Redirects to Active Storage blob URL (short-lived, Rails-managed)
  - If expired or not ready: redirects to `account_path` with alert

### R3: Route

```ruby
resource :account do
  resources :exports, only: %i[create show], controller: "account/exports"
end
```

### R4: Export Job

**New job: `Account::ExportJob`** — Solid Queue job that builds the ZIP file.

Steps:
1. Find the `AccountExport` record, update status to `processing`
2. Create a temp directory with `Dir.mktmpdir`
3. Create account root folder: `account-name/`
4. Iterate `account.workspaces.not_deleted.order(:name)` (includes archived)
5. For each workspace:
   - Create folder: `account-name/workspace-name/`
   - Add `_workspace.yml` metadata file (name, description, archived status, memory count, dates)
   - Query latest-version memories: `workspace.memories.where(parent_memory_id: nil).includes(:content).order(:title)`
   - For each memory:
     - Write `.md` file with YAML frontmatter + body
     - Filename: sanitized title (lowercase, hyphens, truncated to 80 chars) + `.md`
     - Frontmatter: title, tags, source, version, created_at, updated_at
6. ZIP the directory using `Zip::File` (rubyzip, available as transitive dep)
7. Attach ZIP to `AccountExport` via Active Storage: `export.archive.attach(io:, filename:, content_type:)`
8. Update export: `status: "completed"`, `completed_at: Time.current`, `expires_at: 5.days.from_now`
9. Send `AccountExportMailer.completed` email with download link
10. Cleanup: `FileUtils.rm_rf(tmpdir)` in `ensure` block

**Failure handling:**
- Rescue exceptions, set `status: "failed"`, `error_message: e.message`
- Always cleanup temp dir in `ensure`
- Log errors via `Rails.logger.error`

### R5: Cleanup Job

**New job: `Account::ExportCleanupJob`** — recurring Solid Queue job.

- Runs daily (configured in `config/recurring.yml`)
- Finds `AccountExport.where("expires_at < ?", Time.current)`
- For each expired export: purges Active Storage attachment, destroys record
- Also cleans up `failed` exports older than 1 day

### R6: Mailer

**New mailer: `AccountExportMailer`** — inherits from `ApplicationMailer`.

Two emails:
1. **`started(export)`**: Notifies admin that export is being prepared
   - Subject: "Your data export has started"
   - Body: Brief message that export is being created, may take some time

2. **`completed(export)`**: Notifies admin that export is ready
   - Subject: "Your data export is ready"
   - Body: Download link (authenticated), expiry notice (5 days)
   - Download URL: `account_export_url(export)`

### R7: Account Page UI

Add an "Export Data" card to the admin account view (alongside existing cards in the left column).

**New partial: `accounts/_data_export.html.erb`**

Card structure:
- Title: "Data Export"
- Description: Shows export limit status ("X of 2 exports used this month")
- If previous completed export exists and is downloadable:
  - Show download link with expiry date
- Export button (POST to `account_exports_path`):
  - Disabled if monthly limit reached
  - Text: "Request Export"
  - Confirm dialog: "This will create a full backup of all your workspaces and memories. You will receive an email when it's ready."
- If export is currently processing:
  - Show status message: "Export in progress..."
  - Disable button

### R8: File Structure in ZIP

```
account-name/
├── workspace-1/
│   ├── _workspace.yml
│   ├── memory-title-1.md
│   ├── memory-title-2.md
│   └── ...
├── workspace-2/
│   ├── _workspace.yml
│   ├── memory-title-1.md
│   └── ...
└── ...
```

**Memory file format:**
```markdown
---
title: "Memory Title"
tags:
  - tag1
  - tag2
source: "optional source"
version: 3
created_at: "2026-01-15T10:30:00Z"
updated_at: "2026-02-01T14:22:00Z"
---

The markdown body content here...
```

**Workspace metadata (`_workspace.yml`):**
```yaml
name: "Workspace Name"
description: "Optional workspace description"
archived: false
memories_count: 42
created_at: "2026-01-10T08:00:00Z"
updated_at: "2026-02-01T14:22:00Z"
```

### R9: Filename Sanitization

- Replace non-alphanumeric characters (except hyphens) with hyphens
- Collapse multiple hyphens into one
- Strip leading/trailing hyphens
- Truncate to 80 characters
- Downcase
- If empty after sanitization, use `untitled`
- If duplicate filename in same folder, append `-2`, `-3`, etc.

### R10: I18n

All user-facing text in locale files:
- Controller flash messages in `config/locales/controllers/en.yml`
- View text in `config/locales/views/en.yml`
- Mailer subjects in `config/locales/mailers/en.yml`

## Visual Design

The export card follows the same pattern as the existing `_invitations.html.erb` partial — a gem `card` component with title, description, and action area. Placed in the admin column of the account page (left column, after `_danger_zone.html.erb`... actually before it, since danger zone should be last).

## Existing Code to Reuse

| Existing | Reuse for |
|----------|-----------|
| `AdminAuthorizable` concern | Admin-only controller access |
| `ApplicationMailer` | Base mailer with logo attachment |
| `AccountsController` show view | Integration point for export card |
| `accounts/_invitations.html.erb` | Card pattern reference |
| `accounts/_danger_zone.html.erb` | Card pattern reference |
| `Analytics::RecordEventJob` | Job pattern reference |
| `config/recurring.yml` | Recurring job configuration |
| `config/storage.yml` | Active Storage (local disk) already configured |
| `rubyzip` gem | Available as transitive dependency |

## Out of Scope

- API endpoint for triggering exports
- Incremental/delta exports
- Per-workspace exports (always full account)
- Export of user data (sessions, tokens, pins)
- Progress tracking (percentage) during export
- Export format selection (always markdown with frontmatter)
