# Single-Tenant Mode — Task Breakdown

## Task 1: Configuration flag
- Add `config.multi_tenant` to `config/application.rb` (reads `MULTI_TENANT_ENABLED` ENV, default `false`)
- Add `multi_tenant?` helper method in `ApplicationController` (exposed as `helper_method`)

## Task 2: Conditional routes
- Wrap registration route in `if config.multi_tenant`
- Wrap marketing/legal page routes (terms, privacy, api-docs, cli, agents) in `if config.multi_tenant`
- Add `resource :first_run, only: %i[new create]` in `else` branch
- Change root route: multi-tenant → `home#index`, single-tenant → `workspaces#index`
- Keep invitations routes available in both modes (team member invites)
- Keep session, password, account, profile, workspace routes unchanged

## Task 3: FirstRunController
- Create `app/controllers/first_run_controller.rb`
- `allow_unauthenticated_access`
- `before_action :require_no_accounts` (redirect to root if `Account.exists?`)
- `new` action: build `User.new`
- `create` action: call `Account.create_with_user`, start session, redirect to workspaces
- Uses security layout

## Task 4: Authentication concern change
- In `request_authentication`, when not multi-tenant and no accounts exist, redirect to `new_first_run_path`
- Otherwise, existing behavior (redirect to login or render 401 for JSON)

## Task 5: First run view
- Create `app/views/first_run/new.html.erb`
- Security layout card with "Set up your instance" heading
- Email + password + password confirmation fields (same pattern as registration)
- No terms/privacy links, no "Already have an account?" link
- Submit button: "Create account"

## Task 6: Conditional view elements
- `sessions/new.html.erb`: wrap sign-up link in `if multi_tenant?`
- `sessions/new.html.erb`: wrap terms/privacy footer in `if multi_tenant?`
- `passwords/new.html.erb`: wrap terms/privacy footer in `if multi_tenant?` (if present)
- `registrations/new.html.erb`: no changes needed (route is disabled, view unreachable)

## Task 7: I18n translations
- Add `first_run.new.*` and `first_run.create.*` keys to `config/locales/views/en.yml`

## Task 8: Tests
- `test/controllers/first_run_controller_test.rb` — new/create actions, require_no_accounts guard
- Test authentication redirect to first run path
- Verify single-tenant route behavior

## Task 9: Run bin/ci
- Run full CI pipeline to verify nothing is broken
- Fix any lint/test/security issues
