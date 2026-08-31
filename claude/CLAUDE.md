# CLAUDE.md

Recuerd0 — Rails 8 memory/workspace app. SQLite for everything (including cache, jobs, WebSockets via Solid libraries), Kamal deployment, importmaps (no Node.js).

See `docs/technical-guide.md` for architecture, `docs/ui-patterns.md` for UI patterns, `docs/hotwire-patterns.md` for Turbo/Stimulus patterns, `docs/brand-guide.md` for brand guidelines, `docs/API.md` for REST API.

## Workflow Discipline

- When implementing a feature from a plan, ALWAYS re-read the full plan before starting and check off each requirement as you complete it. Before declaring done, verify every planned item was addressed.
- After implementing UI components or interactive elements, verify they work end-to-end by running relevant tests before considering the task complete.
- After making changes, always run `bin/ci` to verify nothing is broken. For quick iteration, `bin/rails test path/to/test.rb` is fine, but always finish with `bin/ci` before declaring done. Run `bin/rubocop` to check lint violations in changed files.

### Definition of Done — REQUIRED, in this order

Work is not done when the tests pass. All four steps below are mandatory; skipping
step 1 means conventions land as an embarrassing self-correcting commit after review
has started, and skipping step 4 means "CI is green" is a claim you have not earned.

1. **Run the convention skills BEFORE pushing.** Conventions are owned by skills, not
   by judgement. Invoke with the **Skill** tool using the full `plugin:skill` name —
   passing one to the Agent tool as `subagent_type` fails with "Agent type not found".
   The naming is not uniform (two repeat the plugin name, two do not), so read it,
   do not infer it:

   | Touched | Skill |
   |---|---|
   | UI, components, ERB | `maquina-ui-standards:ui` |
   | Ruby / Rails structure | `rails-simplifier:simplify` |
   | Stimulus controllers | `better-stimulus:better-stimulus` |
   | Turbo / deep Hotwire | `hotwire-patterns:hotwire-patterns` |

   `bin/rails maquina:doctor` (the gate `maquina-ui-standards` names) does **not**
   exist on maquina-components 0.5.1 — it ships in 0.6.x. Report it as unavailable
   rather than claiming it passed.

2. **Verify interactive work in a browser.** Tests do not exercise JavaScript. A
   Stimulus or Turbo change is unverified until it has been driven for real,
   *including after a refactor of code that already worked*.

3. **Commit and push.**

4. **Run `bin/ci` AGAIN, after the push, and require the Signoff stage to pass.**
   The final stage is `gh signoff`, and it fails with `repository has uncommitted or
   unpushed changes` whenever anything is uncommitted **or** committed-but-unpushed.
   So every mid-work `bin/ci` ends on a red `❌ Continuous Integration failed` even
   when every check before it passed.

   **Do not call that "CI green."** Mid-work, `bin/ci` is a check-runner: say "all
   checks pass, signoff pending — not yet pushed." Only the post-push run can print,
   and only this counts as done:

   ```
   ✓ Signed off on <sha>
   ✅ Continuous Integration passed
   ```

   Signoff records a specific commit SHA, so it must be run against the pushed HEAD.
- After bulk find/replace operations (`replace_all`), always grep the codebase for partial-word matches or typos introduced by the replacement.
- When the user says "continue" or references a Fizzy card, confirm which specific card/task before starting implementation — do NOT assume based on recently viewed cards.
- When opening pull requests, do NOT add a "Generated with Claude Code" line (or any similar attribution footer) to the PR body or commit messages.

## Commands

```bash
bin/dev                          # Start server + Tailwind + Solid Queue (foreman, port 3820)
bin/ci                           # Setup, lint, security audits, tests, seeds
bin/rails test                   # All tests
bin/rails test path/to/test.rb   # Single file
bin/rails test path/to/test.rb:42  # Single test at line
bin/rubocop                      # Check Ruby style (Standard Ruby)
bin/rubocop -a                   # Auto-fix
bin/brakeman                     # Static security analysis
bin/rails db:migrate             # Run migrations
bin/rails search:reindex         # Rebuild FTS5 search index
bin/rails tailwindcss:build      # Build app/assets/builds/tailwind.css
```

`bin/setup` does not build Tailwind, so on a fresh checkout every view-rendering test
errors with `The asset 'tailwind.css' was not found in the load path`. Run
`bin/rails tailwindcss:build` once before `bin/rails test` (`bin/ci` does it for you).

## Architecture

### Tenancy

`MULTI_TENANT_ENABLED` env var (default: `false`) → `Rails.application.config.multi_tenant` / `multi_tenant?` helper. Single-tenant: no registration, root → `workspaces#index`, `FirstRunController` creates first account. Multi-tenant: public registration, marketing pages, root → `home#index`. Test env sets `config.multi_tenant = true`; stub `false` for single-tenant tests.

### Critical Data Isolation

All workspace queries MUST scope to `Current.account.workspaces`. This is security-critical.

### Workspace State Hierarchy

active (default) → archived → deleted. State changes auto-unpin. When refactoring models or changing associations, always check and update `db/seeds.rb`.

### FTS5 Search

Two search scopes in `Searchable` concern: `api_search(query)` passes raw FTS5 syntax and is what **both** `SearchController` formats use — the browser gets the same operators as the API, and invalid syntax is rescued and reported rather than pre-empted. `full_search(query)` wraps the query as a quoted phrase and now serves only the `Memory.search` scope (`app/models/memory.rb`) used by within-workspace and MCP search, where a phrase match is what's wanted. FTS5 errors surface as `ActiveRecord::StatementInvalid` (not `SQLite3::SQLException`); match on `e.message.include?("fts5")`. Always indexes newest version's content under root memory's ID.

### Asset Paths

- Static assets (favicons, icons, `manifest.json`) go in `public/`, NOT `app/assets/images/`
- Propshaft font paths: CSS `url()` must use `url('/filename.woff2')` — not `../fonts/` and not `/assets/filename.woff2`
- After placing or moving assets, verify the path resolves correctly before declaring done

## maquina-components Gem

Components live in the gem (`app/views/components/`), not the app. App-specific components in `app/views/application/components/`.

### Icons — always check `main_icon_svg_for` first

Before using or adding an icon, check `app/helpers/maquina_components_helper.rb` → `main_icon_svg_for(name)`. Add new icons as `when :icon_name` cases. Never use inline SVGs in views — always use `icon_for(:name)`.

### Sub-component content pattern — CRITICAL

Gem sub-components (card/title, card/description, alert/title, toast/title, etc.) use `text || content` — NOT `yield`. Blocks are silently dropped:

```erb
<%# GOOD %>
<%= render "components/toast/title", text: "Saved!" %>
<%= render "components/card/title", content: capture { %><span>Custom</span><% } %>

<%# BAD — silently drops content %>
<%= render "components/toast/title" do %>This won't render<% end %>
```

Same for container components like toaster — use `content:` parameter, not a block.

### Component variants

| Component | Variants |
|-----------|----------|
| alert | `:default`, `:destructive`, `:success`, `:warning` (no `:info`) |
| empty | `:default`, `:outline` (no `:dashed`) |
| badge | `:default`, `:secondary`, `:destructive`, `:warning`, `:outline` |
| toast | `:default`, `:success`, `:info`, `:warning`, `:error` |

### Alert `icon:` parameter

Use the built-in `icon:` local — the component handles `data-has-icon` and CSS grid layout automatically:

```erb
<%= render "components/alert", variant: :warning, icon: :trash_2 do %>
  <strong>Title</strong><p class="mt-1">Description.</p>
<% end %>
```

### Sidebar `active:` parameter

`sidebar/menu_button` accepts `active:` (default `false`) to highlight current section.

### Form data attributes

The gem styles forms via `[data-component]` and `[data-form-part]` selectors. Key attributes: `data-component="form|label|input|textarea|button"`, `data-form-part="group|error"`. Note: `data-form-part="error"` uses `--destructive-foreground` (near-white); for inline error text add `class="text-destructive"`.

When creating compound input components, match the gem's focus ring: `box-shadow: var(--shadow-xs), 0 0 0 3px color-mix(in oklch, var(--ring) 50%, transparent)`.

### I18n lazy lookup gotcha — CRITICAL

Do NOT use `t(".key")` inside blocks passed to gem component partials. Rails resolves lazy scope to the gem partial's path, not your app's:

```erb
<%# BAD — resolves to components.card.header.title %>
<%= render "components/card/header" do %>
  <%= render "components/card/title", text: t(".title") %>
<% end %>

<%# GOOD — use full keys %>
<%= render "components/card/header" do %>
  <%= render "components/card/title", text: t("accounts.details.title") %>
<% end %>
```

View-level locale keys go in `config/locales/views/en.yml`. Partial key paths strip the underscore: `accounts.details.*` (not `accounts._details.*`).

## Turbo / Hotwire Gotchas

- **Form submissions**: Use `redirect_to` after success (Turbo morphs the response). Do NOT use `turbo_stream.refresh` for form responses — silently ignored due to request_id deduplication.
- **Back-button freshness**: Pages with mutable state use `<meta name="turbo-cache-control" content="no-cache">` via `content_for :head`.
- **Teardown pattern**: Controllers with a `teardown()` method get called on `turbo:before-cache` (via `app/javascript/controllers/application.js`). Gem controllers handle their own teardown. Note that a page carrying `turbo-cache-control: no-cache` is never snapshotted, so `turbo:before-cache` — and therefore `teardown()` — never fires there; don't rely on it for cleanup on those pages.
- **Dropdown `auto_close: true`**: All dropdown menus with navigation items use this.
- **Sidebar `cookie_name:`**: Must be `"recuerd0_sidebar_state"` to match server-side helper.
- **`ws-filter` on a bare form**: the controller can be mounted directly on the `<form>` it drives — Stimulus target lookup matches the controller element itself, so `data-controller="ws-filter"` and `data-ws-filter-target="form"` on the same tag resolve fine, no wrapper `div` needed. Do **not** also wrap an ancestor in `data-controller="ws-filter"`: it binds a document-level `keydown` listener, so two instances on one page fight over `/`.
- **Debounced filters need `turbo_action: "replace"`**: with `"advance"` every debounced submit pushes a history entry (Back walks through half-typed queries) and the morph that preserves focus and caret never happens, which makes the input unusable mid-typing.
- **Anything JavaScript writes into the DOM must survive a morph.** A one-shot write in `connect()` against a node the server renders empty gets erased by the next morph, and the controller element usually survives the morph, so `connect()` never re-runs to redo it. The palette's `⌘K` badge lost its text on every filter keystroke this way. Re-render such nodes from the controller's `turbo:morph@document` handler, above any early-return guard in it, or mark the node `data-turbo-permanent`.
- **Browser-drawn chrome is styled once, globally.** `::-webkit-search-cancel-button` (the X in a `type="search"` field) is suppressed by a single unscoped rule in the "Browser surfaces" section of `app/assets/tailwind/application.css`. Scoping that kind of rule to one component class is how the workspaces filter and the memories filter drifted apart. `test/assets/search_input_css_test.rb` guards it.

### System tests

- `bin/ci` does **not** run them (`config/ci.rb` has the step commented out) — run `bin/rails test test/system/...` by hand when you touch JS.
- Headless Chrome cannot start in the container without `--no-sandbox`; the flags live in `test/application_system_test_case.rb`. Without them every system test fails with `SessionNotCreatedError: Chrome instance exited`.
- Rebuild CSS (`bin/rails tailwindcss:build`) after editing `app/assets/tailwind/application.css` or system tests exercise the stale build.
- `getComputedStyle(el, "::-webkit-search-cancel-button")` returns the **host element's** style in headless Chrome, not the pseudo-element's — it reports `appearance: auto` even when the rule applies. Don't assert on it; assert on the CSS source and check the rendering in a screenshot.

## Rails MCP Server

Use `mcp__rails__execute_tool` to call tools, `mcp__rails__search_tools` to discover them.

Load guides: `execute_tool("load_guide", { library: "<library>", guide: "<guide_name>" })`. Omit `guide` to list available guides. Libraries: Rails, Turbo, Stimulus, Kamal.

Other tools: `analyze_models`, `analyze_controller_views`, `get_routes`, `get_schema`, `project_info`.

## Recuerd0 Knowledge Base

The `/recuerd0` skill provides access to project knowledge stored as memories. **When the user asks you to explain an area of the application**, search recuerd0 first — do NOT read source code unless explicitly asked. Fall back to codebase only if no relevant memories found.

```bash
recuerd0 workspace list --pretty              # Find workspaces (look for "recuerd0 Rails Application")
recuerd0 memory list --workspace <id> --pretty # Browse docs in a workspace
recuerd0 search "query terms" --pretty         # FTS5 search (supports AND, OR, NOT, "phrase", title:, body:)
recuerd0 memory show --workspace <id> <memory_id> --pretty
```

Content formats: recuerd0 uses Markdown, fizzy uses HTML.

## Project Tracking (Fizzy)

Engineering tasks on Fizzy board: **Recuerd0 Engineering** (`03fip3ticfveu2xub49cypi30`). Use the `/fizzy` skill to manage cards, comments, and task status — it knows the full CLI syntax.

### Fizzy CLI quick reference

```bash
fizzy card list --board <board_id> --search "query"  # Find cards
fizzy card show <number>                             # Card by number (not ID)
fizzy card close <number>                            # Close a card
fizzy card reopen <number>                           # Reopen a card
fizzy card column <number> --column <column_name>    # Move to column
fizzy comment create --card <number> --body "text"   # Add comment (--card and --body are required flags)
fizzy comment list --card <number>                   # List comments
```

### Key rules

- Use card **number** (e.g. `274`), not the full ID, for most commands
- `fizzy card comment` is NOT a valid subcommand — comments are a separate top-level command: `fizzy comment`
- `fizzy card close/reopen` take only the card number as a positional arg
- `fizzy comment create` requires `--card` and `--body` flags (not positional args)
- When posting comments, always use **HTML format**, never markdown. Fizzy renders HTML content.
- Include the full plan as a comment on the card when closing or updating status.
- When the user says "update the card" or "create a card", refer to the CLI commands above and use the correct syntax and ID formats before invoking.

## Design Context

Frontend/UI work is guided by two root files (created via the `impeccable` skill). Read them before designing, building, or reviewing any UI:

- **`PRODUCT.md`** — strategic: register (`brand`-primary; override to `product` for the app shell), users, product purpose ("the Notion for LLM context"), brand personality (*precise, human, quietly confident*), anti-references, and 5 design principles.
- **`DESIGN.md`** — visual system: OKLCH hue-150 palette (Memory Green primary), Jura / Instrument Sans / Geist Mono type, flat-by-default elevation, and named rules (One Green Rule, True-Neutral Rule, Flat-By-Default Rule, One-Frost Rule). Machine-readable tokens live in its YAML frontmatter; `.impeccable/design.json` carries tonal ramps and component snippets.

These align with `docs/brand-guide.md` and `docs/brand-voice.md`. Use the `impeccable` skill (`/impeccable <command>`) for UI design, critique, audit, and polish work.
