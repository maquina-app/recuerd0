# Spec Verification: Account Data Export

## Date
2026-02-05

## Requirements Accuracy

| Requirement | Matches Q&A? | Notes |
|------------|-------------|-------|
| Export scope: active + archived | Yes | Excludes soft-deleted per user choice |
| Latest version only | Yes | No version history in export |
| Markdown with YAML frontmatter | Yes | Title, tags, source, dates in frontmatter |
| Admin-only access | Yes | Uses AdminAuthorizable concern |
| 2/month calendar limit | Yes | Per account, resets each calendar month |
| Email on start + completion | Yes | Two separate mailer actions |
| 5-day expiry | Yes | Authenticated download link |
| Cleanup job | Yes | Recurring daily via Solid Queue |

## Visual Assets

No custom visual designs needed — uses existing maquina-components gem card pattern matching `_invitations.html.erb`.

## Reusability Opportunities

- [x] AdminAuthorizable concern for controller authorization
- [x] ApplicationMailer base class with logo
- [x] Card component pattern from accounts page
- [x] Solid Queue job pattern from Analytics::RecordEventJob
- [x] Active Storage already configured (local disk)
- [x] rubyzip available (will add as explicit Gemfile dependency)

## Test Limits

| Group | Tests | Within 2-8? |
|-------|-------|-------------|
| Model (AccountExport) | 6 | Yes |
| Job (ExportJob) | 5 | Yes |
| Job (CleanupJob) | 3 | Yes |
| Controller (ExportsController) | 6 | Yes |
| Mailer (AccountExportMailer) | 4 | Yes |
| **Total** | **24** | Within 16-34 |

## Verification Result

**PASS** — Spec is complete, accurate against requirements, and ready for task breakdown.

## Notes

- `rubyzip` gem is available as a transitive dependency (selenium-webdriver) but must be added explicitly to the Gemfile for production reliability since selenium is only in test group
- The export card placement: before `_danger_zone` in admin layout, after `_users`
- Filename sanitization handles edge cases: empty titles, duplicates, special chars
