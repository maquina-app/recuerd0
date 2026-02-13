# Tasks: Transactional Email Improvements

## Overview

- **Spec:** 2026-02-13-transactional-emails
- **Total Task Groups:** 3
- **Estimated Effort:** XS (1 day)
- **Status:** Complete

---

## Task Groups

### Asset & Mailer Setup

#### Task Group 1: Maquina Logo + ApplicationMailer
**Dependencies:** None

- [x] 1.0 Complete logo asset and mailer attachment
  - [x] 1.1 Create `app/assets/images/maquina-email.png` — PNG export of Maquina horizontal logo (2x retina, 240x62px rendered at ~120px wide)
  - [x] 1.2 Update `ApplicationMailer#attach_logo` to also attach `maquina-email.png` inline
  - [x] 1.3 Verify both attachments are present in mailer tests

---

### Layout Footer

#### Task Group 2: Shared Mailer Layout Updates
**Dependencies:** Task Group 1

- [x] 2.0 Complete mailer layout footer improvements
  - [x] 2.1 Update `layouts/mailer.html.erb` footer with copyright + Maquina logo
  - [x] 2.2 Update `layouts/mailer.text.erb` footer with copyright + Maquina text attribution
  - [x] 2.3 Footer propagates to all 5 existing email templates

---

### Email Content

#### Task Group 3: Welcome Email + Missing Text Templates
**Dependencies:** Task Group 2

- [x] 3.0 Complete email content updates
  - [x] 3.1 Update `RegistrationsMailer#welcome` to look up Start Here workspace
  - [x] 3.2 Rewrite `registrations_mailer/welcome.html.erb` with Start Here, API/CLI/agents
  - [x] 3.3 Rewrite `registrations_mailer/welcome.text.erb` to mirror HTML
  - [x] 3.4 Create `account_export_mailer/started.text.erb`
  - [x] 3.5 Create `account_export_mailer/completed.text.erb`
  - [x] 3.6 Run `bin/rails test` — 338 tests, 931 assertions, 0 failures
  - [x] 3.7 Run `bin/rubocop` — no offenses

---

## Progress Log

| Date | Task | Status | Notes |
|------|------|--------|-------|
| 2026-02-13 | Task Group 1 | Complete | Maquina PNG created via rsvg-convert, ApplicationMailer updated |
| 2026-02-13 | Task Group 2 | Complete | Both HTML and text layout footers updated |
| 2026-02-13 | Task Group 3 | Complete | Welcome email rewritten, 2 missing text templates created |
| 2026-02-13 | XSS test fix | Complete | Updated search test assertion to account for Plausible script in layout |
