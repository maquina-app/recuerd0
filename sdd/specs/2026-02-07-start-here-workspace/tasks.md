# Tasks: Start Here Workspace

## Overview

- **Spec:** 2026-02-07-start-here-workspace
- **Total Task Groups:** 3
- **Estimated Effort:** S (2-3 days)
- **Status:** In Progress

---

## Task Groups

### Model Layer

#### Task Group 1: Account Seeding Method
**Dependencies:** None

- [ ] 1.0 Complete Account seeding implementation
  - [ ] 1.1 Write 5 focused tests for seeding behavior
    - Test `seed_start_here_workspace` creates workspace named "Start Here"
    - Test creates exactly 5 memories with correct titles
    - Test each memory has content (non-empty body)
    - Test memories have source set to "system"
    - Test "Why recuerd0" memory is pinned for the given user
  - [ ] 1.2 Add `seed_start_here_workspace(user)` method to Account model
    - Creates workspace named "Start Here"
    - Creates 5 memories with markdown content via `Memory.create_with_content`
    - Pins "Why recuerd0" memory for the user
    - All tags include "getting-started"
  - [ ] 1.3 Write markdown content for each memory
    - "Why recuerd0" — product overview, problem, solution
    - "Quick Manual" — account, users, invitations, tokens, export
    - "The API" — authentication, endpoints, rate limits, errors
    - "The CLI" — installation, quick start, key commands
    - "The Agent" — three layers, setup, workflows, integrations
  - [ ] 1.4 Integrate into `Account.create_with_user`
    - Call `account.seed_start_here_workspace(user)` after user creation
    - Keep within the existing transaction
  - [ ] 1.5 Ensure model tests pass
    - Run ONLY tests from 1.1

**Acceptance Criteria:**
- [ ] All tests from 1.1 pass
- [ ] Workspace created with 5 memories on account creation
- [ ] "Why recuerd0" memory pinned for admin user
- [ ] Content is meaningful markdown, follows brand voice

---

### Registration Integration

#### Task Group 2: Registration Flow Tests
**Dependencies:** Task Group 1

- [ ] 2.0 Complete registration integration
  - [ ] 2.1 Write 3 focused tests for registration with seeding
    - Test registration creates "Start Here" workspace
    - Test registration creates seeded memories
    - Test account creation failure does not leave partial workspace
  - [ ] 2.2 Verify RegistrationsController flow works end-to-end
    - Account.create_with_user now seeds automatically
    - No controller changes needed
  - [ ] 2.3 Ensure registration tests pass
    - Run ONLY tests from 2.1

**Acceptance Criteria:**
- [ ] All tests from 2.1 pass
- [ ] Registration flow creates account + user + workspace + memories atomically
- [ ] Failed registration leaves no orphaned records

---

### Seeds & Verification

#### Task Group 3: Development Seeds & Final Verification
**Dependencies:** Task Groups 1-2

- [ ] 3.0 Complete seeds and verification
  - [ ] 3.1 Write 2 focused integration tests
    - Test that seeding is idempotent (calling twice doesn't duplicate)
    - Test search index works for seeded memories
  - [ ] 3.2 Update db/seeds.rb to use the new seeding method
    - Replace or supplement existing demo account seeding
    - Ensure demo account gets "Start Here" workspace
  - [ ] 3.3 Run full test suite via `bin/ci`
  - [ ] 3.4 Verify seeds work: `bin/rails db:seed`

**Acceptance Criteria:**
- [ ] All tests pass
- [ ] `bin/ci` passes
- [ ] `bin/rails db:seed` works correctly
- [ ] Seeded memories are searchable

---

## Execution Order

1. Model Layer (Task Group 1)
2. Registration Integration (Task Group 2)
3. Seeds & Verification (Task Group 3)

---

## Progress Log

| Date | Task | Status | Notes |
|------|------|--------|-------|
