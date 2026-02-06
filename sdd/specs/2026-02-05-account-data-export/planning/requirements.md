# Requirements: Account Data Export

## Date
2026-02-05

## Feature Summary
Allow account admins to download a complete ZIP backup of their account data (workspaces and memories as a file system). Limited to 2 requests per calendar month. Asynchronous via Solid Queue with email notifications.

## Requirements Q&A

### Q1: Export scope — which workspace states to include?
**A:** Active + archived only. Soft-deleted workspaces and their memories are excluded from the export.

### Q2: Memory versioning — include all versions or latest only?
**A:** Latest version only. Export the most recent version of each memory for cleaner, smaller files.

### Q3: File format for exported memories?
**A:** Markdown with YAML frontmatter. Each memory exported as `.md` file with title, tags, source, dates in YAML frontmatter followed by the markdown body content.

### Q4: Who can request exports?
**A:** Admin only. Consistent with other account-level actions in the application (uses AdminAuthorizable concern).

## Functional Requirements

### Request Flow
1. Admin navigates to account page and clicks "Export Data" button
2. System checks 2-per-calendar-month limit
3. If within limit: enqueues export job, sends "export started" email, shows toast confirmation
4. If limit exceeded: shows error message, no job enqueued

### Export Job (Solid Queue)
1. Creates temporary directory structure: `account-name/workspace-name/memory-title.md`
2. Iterates active + archived workspaces (not soft-deleted)
3. For each workspace: creates folder, iterates latest-version memories
4. For each memory: writes `.md` file with YAML frontmatter (title, tags, source, created_at, updated_at) + body
5. Zips the directory structure
6. Uploads ZIP to Active Storage attached to Account
7. Cleans up temporary directory
8. Sends "export ready" email with authenticated download link

### Download Link
- Requires authentication (session-based, same as app)
- Expires after 5 days from creation
- Served via a dedicated controller action with admin authorization

### Cleanup Job
- Periodic job removes backups older than 5 days
- Runs as a recurring Solid Queue job
- Purges Active Storage attachments (blob + file)

### Email Notifications
1. **Export Started**: Sent immediately when job is enqueued. Informs user backup is being created.
2. **Export Ready**: Sent when ZIP is uploaded. Contains download link.

## Non-Functional Requirements
- ZIP file uses standard `zlib` (Ruby stdlib) — no external gems needed
- Filenames sanitized (no special characters, max length)
- Temporary files cleaned up even on job failure
- Rate limit: 2 exports per calendar month per account

## Out of Scope
- API endpoint for triggering exports (HTML-only for now)
- Incremental/delta exports
- Per-workspace exports (always full account)
- Export of user data (sessions, tokens, pins)
