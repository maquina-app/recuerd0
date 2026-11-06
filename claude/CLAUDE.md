# CLAUDE.md

Recuerd0 — Rails 8 memory/workspace app. SQLite for everything (including cache, jobs, WebSockets via Solid libraries), Kamal deployment, importmaps (no Node.js).

**Auth is not Clave and not Devise**, unlike the other maquina apps: the Rails 8 generator's `has_secure_password` with a signed `session_id` cookie (`Authentication` concern, `new_session_path`), plus Bearer access tokens and OAuth for the API and MCP.

## Knowledge Base

**When the user asks you to explain an area of the application**, search Recuerd0 first with the `recuerd0:remember` skill. Do NOT read source code unless explicitly asked; fall back to it only if no relevant memories are found.

Workspace 26 ("recuerd0 Rails Application") has one reference per area, checked against the code. Read it before the older memories it links to, and version it when the area changes: `recuerd0 memory show --workspace 26 <id>`.

| Area | Memory |
|------|--------|
| Technical Guide, the hub: stack, jobs, deploy, CI | 98 |
| REST API (endpoint list: 101, `docs/API.md`) | 179 |
| MCP and OAuth | 695 |
| Security | 4076 |
| Account management, ownership | 117 |
| Memories and versioning | 104 |
| Search: FTS5 and the semantic fallback | 4098 |
| Flows | 178 |
| Brand | 102 |

## Workflow Discipline

- When implementing a feature from a plan, ALWAYS re-read the full plan before starting and check off each requirement as you complete it. Before declaring done, verify every planned item was addressed.
- For quick iteration, `bin/rails test path/to/test.rb` is fine. Always finish with the Definition of Done below.
- After bulk find/replace operations (`replace_all`), always grep the codebase for partial-word matches or typos introduced by the replacement.
- When the user says "continue" or references a Fizzy card, confirm which specific card/task before starting implementation — do NOT assume based on recently viewed cards.
- Commits and PR bodies carry no "Generated with Claude Code" line or any similar attribution footer.

### Definition of Done — REQUIRED, in this order

Work is not done when the tests pass. Skipping step 1 means conventions land as an embarrassing self-correcting commit after review has started, and skipping step 4 means "CI is green" is a claim you have not earned.

1. **Run the convention skills BEFORE pushing.** Invoke with the **Skill** tool using the full `plugin:skill` name. Passing one to the Agent tool as `subagent_type` fails with "Agent type not found". The naming is not uniform, so read it, do not infer it:

   | Touched | Skill |
   |---|---|
   | UI, components, ERB | `maquina-ui-standards:ui` |
   | Ruby / Rails structure | `rails-simplifier:simplify` |
   | Stimulus controllers | `better-stimulus:better-stimulus` |
   | Turbo / deep Hotwire | `hotwire-patterns:hotwire-patterns` |

   Then read `bin/rails maquina:doctor`. It never edits and always exits 0. BREAKING must be empty apart from the known false positive: on 0.7.4 its `destructive-error-invisible` rule ignores the `--destructive-text` / `--destructive-border` tokens that fix it, so those two lines stay. The remaining REVIEW/CLEANUP findings are the toast restyle and app rules that deliberately sit outside a layer.

2. **Verify interactive work in a browser.** Tests do not exercise JavaScript. A Stimulus or Turbo change is unverified until it has been driven for real, *including after a refactor of code that already worked*.

3. **Commit and push.**

4. **Run `bin/ci` AGAIN, after the push, and require the Signoff stage to pass.** `gh signoff` fails with `repository has uncommitted or unpushed changes`, so every mid-work `bin/ci` ends on a red `❌ Continuous Integration failed` even when every check passed. **Do not call that "CI green."** Say "all checks pass, signoff pending — not yet pushed." Only this counts as done, against the pushed HEAD:

   ```
   ✓ Signed off on <sha>
   ✅ Continuous Integration passed
   ```

## Commands

`bin/dev` runs the server, Tailwind and Solid Queue on port 3820. `bin/ci` runs setup, lint, security audits, tests and seeds. `bin/rails search:reindex` rebuilds the FTS5 index.

`bin/setup` does not build Tailwind, so on a fresh checkout every view-rendering test errors with `The asset 'tailwind.css' was not found in the load path`. Run `bin/rails tailwindcss:build` once before `bin/rails test` (`bin/ci` does it for you).

## Architecture

### Critical Data Isolation

All workspace queries MUST scope to `Current.account.workspaces`. This is security-critical.

### Tenancy

`MULTI_TENANT_ENABLED` (default `false`) sets `config.multi_tenant` and the `multi_tenant?` helper. Routes compile at boot. The test env sets it to true, so every route exists; stub `false` for single-tenant tests.

### Workspace State Hierarchy

active (default) → archived → deleted. State changes unpin the workspace, not its memories. When refactoring models or changing associations, always check and update `db/seeds.rb`.

### Search

One search contract for web, REST and MCP: `Memory.search`. Do not add a second search path; results must stay identical across surfaces. Never fuse or reorder the keyword list with embeddings: unweighted RRF demoted exact matches on the retrieval bench (D022), so they only fill in when keyword search comes up nearly empty. Show each hit as its current version by preloading `latest_version`, never `includes(:child_versions)` next to a `where(workspaces: …)`, which turns into an eager-load JOIN over every version and a ~1s `COUNT(DISTINCT)`. Memory 4098 has the rest.

### Ownership

Members change, delete, archive, restore and purge only what they own; admins can do it to anything; anyone can add a version. A workspace's owner can also delete what's in it, and that reaches delete only. `Ownable#manageable_by?` is the rule, `Memory#deletable_by?` adds the workspace owner, `OwnershipAuthorizable` enforces both on web and REST, and `update_memory` checks it on MCP. Views hiding a control isn't enforcement.

- MCP has no delete, archive or purge tool; if one is added it needs the same check. Its write tools refuse an archived workspace themselves, because `find_memory` keeps archived memories readable.
- A handover deliberately touches nothing, so `owner_id` has to stay out of `json.cache!` and be part of any ETag on a record that reports it.
- `User#remove_from_account!` is the only way to remove someone: it revokes their tokens and OAuth grants, passes on what they own, and revokes unused invitation links.

Memory 117 has the full rule, handover, invitations, account deletion and retention. `Account#purge!` destroys workspaces one by one first, because `dependent: :destroy` would only soft-delete them.

### Memories and versions

- `/memories/<root id>` always opens the current version. Link with `stable_memory_path` / `version_page_path`, not `workspace_memory_path(workspace, version)`.
- Editing has two explicit outcomes, `save_as=new_version` (primary, Cmd+S) and `save_as=in_place`; there is no autosave. A plain PATCH, the REST contract, means in place. The primary button is first in the DOM and last on screen, because Enter presses the first submit button.
- A root row is v1 and also what filters read. Its `tags` and `category` follow the current version, and anything showing one specific version reads `version_tags` / `version_category`. Its `title` and `source` stay v1's, so show a root through `current_version`, and filter or sort roots with `with_current_title_like`, `with_current_source` and `ordered_by("title")`.
- `create_version!` fills omitted fields from the row it is called on, so callers choose that row deliberately. REST and MCP resolve to the current version and use `create_changed_version`, which refuses a result identical to it.
- `memories_count` counts roots only, and links always attach to the root.

Memory 104 has the rest, including conflicts, restore and purge.

### Asset Paths

- Static assets (favicons, icons, `manifest.json`) go in `public/`, NOT `app/assets/images/`
- Propshaft font paths: CSS `url()` must use `url('/filename.woff2')` — not `../fonts/` and not `/assets/filename.woff2`
- After placing or moving assets, verify the path resolves correctly before declaring done

## UI

maquina-components is the component catalog: the `maquina-ui-standards:ui` skill and https://maquina.app/documentation/components/. Components live in the gem (`app/views/components/`); app-specific ones are in `app/views/application/components/`. The catalog owns props and variants, but these catch people out: alert has no `:info`, empty has no `:dashed`, and the toaster takes `content:`, not a block.

- **Icons:** before using or adding one, check `main_icon_svg_for(name)` in `app/helpers/maquina_components_helper.rb`. Add new ones as `when :icon_name` cases. Never use inline SVGs in views; always use `icon_for(:name)`.
- **Invalid fields:** the field must say it's invalid with `aria: { invalid: record.errors[:field].any? }`, because the engine keys the error border on `aria-invalid` / `:user-invalid`, and a server-rendered error on an untouched field matches neither. `<p data-form-part="error">` needs no colour utility.
- **Compound inputs** (a bordered shell around a bare input): add the shell to the grouped "Compound fields" rule in `application.css`. Never transition `outline-color` on it.

Read `PRODUCT.md` and `DESIGN.md` before designing, building, or reviewing any UI, and take numbers from `application.css` where they disagree. Use the `impeccable` skill for design, critique, audit and polish work. Memory 102 has positioning, voice and tokens.

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
- **`<house-md>` must be `data-turbo-permanent` with a per-record `id`.** It builds its editable area and hidden input once, in `connectedCallback`, and a morph reuses the element without re-running it. A failed form save comes back as a morph, so without this the editor goes dead and the next save sends no content, and reads as a success. Don't use a shared id: permanent elements are matched by id across pages.
- **Browser-drawn chrome is styled once, globally.** `::-webkit-search-cancel-button` (the X in a `type="search"` field) is suppressed by a single unscoped rule in the "Browser surfaces" section of `app/assets/tailwind/application.css`. Scoping that kind of rule to one component class is how the workspaces filter and the memories filter drifted apart. `test/assets/search_input_css_test.rb` guards it.

## Testing Gotchas

- **`Foreign key violations found: memory_links` after `bin/ci`** is environment state, not a broken test. Its seed step leaves rows in the test database, and a run under 50 tests loads fixtures onto that file, which deletes the memories those rows point at. Run `bin/rails db:test:prepare`. `db:reset` does not help, because it re-seeds.
- **`check_box_tag` vs `f.check_box`**: only the form-builder version emits the paired hidden "0" field. A GET filter checkbox that must send *nothing* when unchecked (the search page's `include=obsolete`) has to be `check_box_tag`, or every unchecked submit carries `include=0`.
- **`Workspaces::ContextResolver` prefers pins**: a test that wants the *recent* branch must clear pins first (`Pin.destroy_all`) — fixtures pin memories for `users(:one)`, so a freshly created memory never appears in the returned context otherwise.
- **Two users in one integration test**: `sign_in_as` posts to `SessionsController#create`, which has `before_action :redirect_authenticated_user` — a second `sign_in_as` in the same test is silently redirected and you keep the FIRST user's session (and its response bodies/ETags). Always `delete session_url` before signing in as somebody else.
- **`assert_no_queries` and fixtures**: `users(:one)` inside the block issues its own SELECT. Resolve every fixture into a local before the block or the assertion fails on the fixture lookup, not on the code under test.
- **Search tests** use `FakeEmbeddingProvider` + `with_hybrid_retrieval` + `create_memory_embedding`; create memories with the flag off so callbacks don't embed them first.

### System tests

**Don't add more.** `test/system/onboarding_dismissal_test.rb` and `search_shortcut_hint_test.rb` stay as a named exception to the no-system-tests rule (owner's decision, 2026-11-05). New coverage goes in `test/integration/`. `bin/ci` doesn't run them, so run `bin/rails test test/system/...` by hand when you touch what they cover, after `bin/rails tailwindcss:build` if the CSS changed.

- Headless Chrome cannot start in the container without `--no-sandbox`; the flags live in `test/application_system_test_case.rb`.
- `getComputedStyle(el, "::-webkit-search-cancel-button")` returns the **host element's** style in headless Chrome, not the pseudo-element's. Don't assert on it; assert on the CSS source and check the rendering in a screenshot.

## Project Tracking (Fizzy)

Engineering tasks are on the **Recuerd0 Engineering** board (`03fip3ticfveu2xub49cypi30`). Use the `/fizzy` skill for cards, comments and status; it knows the CLI syntax. Search before creating a card.

- Post comments in **HTML**, never Markdown. Fizzy renders HTML.
- Include the full plan as a comment on the card when closing or updating status.

## Gotchas

- A `parent_memory` preload re-loads the roots a collection already holds, as separate instances whose `child_versions` are NOT loaded — so anything asking a version whether it is current (`current_version?`) costs one query per root. When every version is already in the result set, point the children at the loaded roots instead (`Workspaces::ExportsController#link_parents_to_loaded_roots`).
- `invert_where` inverts EVERY where clause on the relation, not just the last one. For "the rows this filter withheld", write the positive predicate (as `Memory.only_obsolete` does).
- Archiving or deleting a workspace does not touch its memories, so any fragment cache that renders workspace state must include the workspace in its key (`app/views/memories/_memory.json.jbuilder`).
- In dev, agent-browser cannot submit the sign-in form (no POST ever reaches the server). Log in with curl (`GET /session/new` → scrape `authenticity_token` → `POST /session` with a cookie jar), then hand the cookie over: `agent-browser cookies set --curl <file> --domain localhost --url http://localhost:3820`. The jar file is Netscape format and `--curl` rejects it — write a single `session_id=<value>` Cookie-header line instead.
- Destroying a version child fires `Searchable#delete_search_index`, which deletes the **root's** FTS row (the index is keyed by root id), and nothing re-inserts it. Any code that destroys versions while the memory survives must call `root.rebuild_search_index` after the transaction commits (`Memory#purge_versions!` does).
- `db:migrate`, or `bin/ci` setup on a checkout whose dev database is behind, can re-dump `db/schema.rb` with columns reordered. That isn't a real change: restore the file, or signoff refuses a dirty tree.
