# Spec Verification: Account Management

**Date:** 2026-02-05
**Status:** Verified

## Requirements Coverage

| Requirement | Covered in Spec | Notes |
|-------------|-----------------|-------|
| Account name editing | Yes (Req 1) | Form pattern matches workspace edit |
| User list display | Yes (Req 2) | Owner identified by earliest created_at |
| User removal | Yes (Req 3) | Email anonymization, session destruction |
| Invitation links | Yes (Req 4) | MessageEncryptor, 7-day expiry |
| Invitation acceptance | Yes (Req 5) | Modified registration, token validation |
| User limit (5) | Yes (Req 6) | Enforced on generation and acceptance |
| Account deletion | Yes (Req 7) | Soft delete, email anonymization, session destruction |
| Terms update | Yes (Req 8) | Section 7, 30-day mention |
| Login blocking | Yes (Req 9) | Auth concern checks account.deleted? |
| Sidebar link | Yes (Req 10) | Wire to account_path |

## Visual Assets

- Sidebar dropdown screenshot reviewed for entry point context
- No high-fidelity mockups — spec describes layout following existing patterns

## Reusability Check

- SoftDeletable concern identified for Account model
- Workspace edit form pattern documented for account name form
- Authentication concern extension documented for login blocking
- Registration flow reuse documented for invitation acceptance

## Test Limits Compliance

- Spec allows 2-8 tests per task group (to be validated in tasks.md)
- No excessive test requirements specified

## Scope Boundaries

- In scope: 10 requirements clearly defined
- Out of scope: 10 items explicitly listed (billing, notifications, API tokens, export, restoration, roles, email sending, cleanup job, API endpoints, ownership transfer)

## Issues Found

None — spec is consistent with requirements document.
