# Specification: Start Here Workspace

## Goal

Automatically seed a "Start Here" workspace with five onboarding memories when a new account is created, giving users a ready-made introduction to recuerd0's capabilities and a quick-reference manual.

## User Stories

- As a new user, I want to find a "Start Here" workspace with useful content so that I understand what recuerd0 can do and how to use it
- As a new admin, I want the "Why recuerd0" memory pinned so that the most important context is immediately visible
- As a developer, I want the onboarding content to cover the API, CLI, and Agent so that I can start integrating right away

## Specific Requirements

**Workspace Creation**
- Create a workspace named "Start Here" belonging to the new account
- Workspace is a normal workspace — can be archived, deleted, renamed by the user

**Memory Content**
- Create 5 memories with source set to `"system"`:
  1. **"Why recuerd0"** — product overview: what it is, the problem it solves, how it helps. Tags: `["getting-started", "overview"]`
  2. **"Quick Manual"** — account management, user profiles, invitations, access tokens, data export. Tags: `["getting-started", "manual"]`
  3. **"The API"** — REST API overview: authentication (Bearer tokens), rate limits, key endpoints, error format. Tags: `["getting-started", "api"]`
  4. **"The CLI"** — installation, quick start, key commands (account, workspace, memory, search). Tags: `["getting-started", "cli"]`
  5. **"The Agent"** — AI agent integration: three layers, project setup, workflows, integrations. Tags: `["getting-started", "agent"]`

**Pinning**
- Pin the "Why recuerd0" memory for the admin user who created the account

**Trigger**
- Seeding happens in `Account.create_with_user` after the user is created, within the same transaction
- Add a `seed_start_here_workspace` method to Account that accepts the admin user
- The method creates the workspace, memories, and pin atomically

**Content Guidelines**
- Markdown format
- Concise — each memory should be 15-40 lines of markdown
- Follow brand voice: direct, technical, no hype
- Reference actual product URLs (e.g., API docs path, CLI path, agents path) where relevant
- Use the product's actual terminology: workspaces, memories, versions, content

## Existing Code to Leverage

**`Account.create_with_user`**
- Already wraps account + user creation in a transaction
- Add the seeding call here after user creation
- Path: `app/models/account.rb`

**`Memory.create_with_content`**
- Creates memory + content in a transaction
- Accepts workspace, title, content, tags, source
- Path: `app/models/memory.rb`

**`Pinnable#pin!`**
- Pins a record for a user
- Path: `app/models/concerns/pinnable.rb`

**`db/seeds.rb`**
- Existing seed file — can be updated to use the same method
- Path: `db/seeds.rb`

## Out of Scope

- I18n translations of seed content
- UI changes or special workspace styling
- Migration to add "Start Here" workspace to existing accounts
- Making the workspace immutable or read-only
- Customizable onboarding content
