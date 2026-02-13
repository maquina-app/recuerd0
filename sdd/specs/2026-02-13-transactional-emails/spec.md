# Spec: Transactional Email Improvements

**Date:** 2026-02-13

## Goal

Improve all transactional emails with a branded footer (copyright + Maquina attribution) in the shared layout, and rewrite the welcome email to guide new users toward the Start Here workspace, the REST API, CLI, and AI agent integrations.

## User Stories

- As a new user, I want the welcome email to tell me about the Start Here workspace so that I know exactly where to begin after creating my account
- As a new user, I want the welcome email to mention the API, CLI, and agents so that I understand the full scope of what recuerd0 offers
- As any email recipient, I want to see proper copyright and Maquina branding in the footer so that emails feel professional and trustworthy

## Specific Requirements

**R1: Mailer Layout Footer (`layouts/mailer.html.erb`)**
- Replace the current minimal footer with a branded footer
- Add copyright line: "&copy; 2026 recuerd0 - Mario Alberto Chávez"
- Add "Designed & built by" text with inline Maquina logo linking to https://maquina.app
- Keep the existing tagline ("recuerd0 — LLM context management")
- Style the footer to match the professional tone of the marketing footer (centered, muted colors, small text)

**R2: Maquina Logo Inline Attachment**
- Create a PNG version of `maquina_logo_horizontal.svg` for email use (SVGs are unreliable in email clients)
- Save as `app/assets/images/maquina-email.png` (2x retina, rendered at ~60px width)
- Attach inline in `ApplicationMailer#attach_logo` alongside the existing recuerd0 logo
- Reference via `attachments["maquina-email.png"].url` in the layout

**R3: Welcome Email Content Rewrite (`registrations_mailer/welcome.html.erb`)**
- Greeting: "Welcome to recuerd0!"
- Brief intro: what recuerd0 is (1 sentence)
- Feature highlights (concise bullet list):
  - Workspaces to organize memories by project or topic
  - Memories with markdown, tagging, and versioning
  - Full-text search across all content
- Where to start: call out the "Start Here" workspace by name, explain it contains onboarding content covering the product overview, account manual, API, CLI, and agents
- Developer tools section (brief):
  - REST API with personal access tokens
  - CLI tool for terminal workflows
  - AI agent integrations
- CTA button: "Open Start Here" linking to the Start Here workspace
- Privacy line: "Your data belongs to you."

**R4: Welcome Email Plain Text (`registrations_mailer/welcome.text.erb`)**
- Mirror the HTML content in plain text format
- Include a URL to the Start Here workspace instead of a button

**R5: Plain Text Layout Footer (`layouts/mailer.text.erb`)**
- Add copyright line and "Designed & built by Maquina — https://maquina.app" to the text layout footer

**R6: Account Export Text Templates**
- Create missing plain text versions for `account_export_mailer/started.text.erb` and `account_export_mailer/completed.text.erb`
- Content mirrors their HTML counterparts

## Existing Code to Leverage

**`ApplicationMailer#attach_logo`**
- Already attaches recuerd0 logo inline; extend to also attach Maquina logo
- Path: `app/mailers/application_mailer.rb`

**`layouts/mailer.html.erb`**
- Shared HTML layout for all emails; footer changes here propagate to all mailers
- Path: `app/views/layouts/mailer.html.erb`

**Marketing footer pattern**
- Copyright: `&copy; 2026 recuerd0 - Mario Alberto Chávez`
- Maquina: `Designed & built by` + logo image linking to https://maquina.app
- Path: `app/views/pages/_marketing_footer.html.erb`

**Start Here workspace**
- Created in `Account.create_with_user` → `seed_start_here_workspace`
- The welcome email needs the workspace URL; find it via `@user.account.workspaces.find_by(name: "Start Here")`
- Path: `app/models/account.rb`

**Existing email templates**
- 5 HTML templates + 3 text templates across 4 mailers
- Missing text templates: `account_export_mailer/started.text.erb`, `account_export_mailer/completed.text.erb`

## Out of Scope

- Redesigning the email layout header or card structure
- Adding new mailer actions
- I18n for email body content (currently hardcoded English)
- Email preview setup (letter_opener handles this in development)
- Responsive email CSS beyond what already exists
- Dark mode email support
