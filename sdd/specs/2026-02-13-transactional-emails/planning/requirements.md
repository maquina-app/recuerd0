# Requirements: Transactional Email Improvements

## Date: 2026-02-13

## Source

User request to improve transactional emails with better content, footer branding, and onboarding guidance.

## Q&A

**Q1: What's the main problem with the current welcome email?**
It's generic — lists features but doesn't tell the user where to start. The "Start Here" workspace is created on account setup but the welcome email doesn't mention it. Users should know exactly what to do after signing up: explore the Start Here workspace, learn about the API, CLI, and AI agents.

**Q2: Should the footer improvements apply to all emails or just welcome?**
All transactional emails. The shared mailer layout (`layouts/mailer.html.erb`) should include copyright and Maquina attribution so every email gets it.

**Q3: How should the Maquina logo be included in emails?**
Inline PNG attachment, matching the pattern used for the recuerd0 logo. SVGs are unreliable in email clients. A PNG version of `maquina_logo_horizontal.svg` needs to be created and attached via `ApplicationMailer`.

**Q4: What should the welcome email communicate?**
- Confirmation that account is ready
- What you can do: workspaces, memories, versioning, search
- Where to start: the "Start Here" workspace with onboarding content
- Developer tools: REST API, CLI tool, AI agent integrations
- Data privacy assurance

**Q5: What does the current mailer layout footer look like?**
Minimal — just "recuerd0 — LLM context management" and tagline. No copyright, no Maquina attribution.

**Q6: What should the new footer include?**
- Copyright line: "2026 recuerd0 - Mario Alberto Chávez"
- "Designed & built by" with Maquina logo (inline PNG) linking to https://maquina.app
- Matches the marketing footer pattern

## Current State

### Mailers (5 actions across 4 mailers)
1. `RegistrationsMailer#welcome` — welcome email on account creation
2. `PasswordsMailer#reset` — password reset link
3. `ProfileMailer#password_changed` — password change notification
4. `AccountExportMailer#started` — export in progress notification
5. `AccountExportMailer#completed` — export ready with download link

### Layout
- `layouts/mailer.html.erb` — shared HTML layout with header (recuerd0 logo), content area, minimal footer
- `layouts/mailer.text.erb` — plain text layout
- `ApplicationMailer` attaches recuerd0 logo inline via `before_action :attach_logo`

### Start Here Workspace
- Created in `Account.create_with_user` → `seed_start_here_workspace`
- 5 memories: "Why recuerd0", "Quick Manual", "The API", "The CLI", "The Agent"
- "Why recuerd0" is pinned for the admin user

## Visuals
- No mockups provided. Reference the marketing footer for the Maquina attribution pattern.
