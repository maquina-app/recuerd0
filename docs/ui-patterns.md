# Recuerd0 UI Patterns Guide

Reference for every UI pattern used across the application. All components come from the maquina-components gem unless noted. Styling uses Tailwind CSS 4 with oklch colors (green primary, hue 150).

## Layouts

### Application Layout

Full-height flex container with sidebar provider wrapping the entire page.

```
body
  toaster (bottom-right, renders flash messages)
  div.flex.h-screen.overflow-hidden
    sidebar/provider (default_open from cookie, variant: inset)
      sidebar (collapsible: offcanvas, variant: inset)
        sidebar/header  → logo + app name
        sidebar/content → navigation groups
        sidebar/footer  → user dropdown
      sidebar/inset
        header (h-[--header-height], shrink-0)
          sidebar/trigger + separator + breadcrumb|title
        div.flex.flex-1.flex-col.overflow-hidden
          div.@container/main
            main.flex-1.p-4.md:p-6.overflow-y-auto
              yield
  turbo_confirm_dialog
```

Turbo morph mode is enabled (`turbo_refresh_method_tag :morph`, `turbo_refresh_scroll_tag :preserve`).

### Security Layout

Centered card on muted background for login/password pages.

```
body
  div.min-h-screen.bg-muted.flex.flex-col.items-center.justify-center.gap-6.p-6.md:p-10
    div.w-full.max-w-sm.space-y-6
      logo link
      flash alerts (auto-dismiss 5s, with manual close button)
      yield
```

## Page Containers

All pages use `mx-auto max-w-4xl` as the content container. The memory editor is the exception -- it uses `h-full flex flex-col` to fill the viewport.

### content_for Blocks

Every page sets two blocks consumed by the layout header:

```erb
<% content_for :page_title, "Page Title" %>

<% content_for :breadcrumb do %>
  <%= breadcrumbs({ "Parent" => parent_path }, "Current Page") %>
<% end %>
```

If `:breadcrumb` is not set, the header falls back to displaying `:page_title` as an `<h1>`.

## Page Types

### Index (List)

```
header row:  h1.text-2xl.font-bold.tracking-tight  +  action button (right-aligned)
content:     list or grid of items, with pagination
fallback:    empty state component
```

### Show (Detail)

```
header row:  h1 + badges (version, pinned) + action buttons/dropdown
state alert: warning/default alert if archived/deleted (mb-6)
metadata:    flex.items-center.gap-4.text-sm.text-muted-foreground
separator
main content
```

### New/Edit (Standard Form)

```
card wrapper:
  card/header → card/title + card/description
  card/content → form partial
```

### New/Edit (Editor — Memory)

No card wrapper. Full-height flex layout:

```
div.h-full.flex.flex-col
  [version alert if editing non-latest, shrink-0]
  div.flex-1.min-h-0
    form partial (fills available space)
```

## Sidebar

### Navigation Structure

```erb
sidebar/group title: "Section Name"
  sidebar/menu
    sidebar/menu_item
      sidebar/menu_button title:, url:, icon_name:, active:
```

Active state set via `active: current_page?(path)`.

### User Footer

Dropdown menu trigger with avatar, username (extracted from email), and email. Opens upward (`side: :top`). Contains account links and sign-out action.

### State Persistence

Sidebar open/closed state stored in cookie `recuerd0_sidebar_state`, loaded in `ApplicationController#load_ui_cookies`.

## Cards

### Workspace List Item

Horizontal row with hover reveal:

```
div.group.flex.items-center.gap-4.px-4.py-3.rounded-lg.hover:bg-accent/50
  [pin icon if pinned, rotate-45, text-primary]
  name link + status badge + description (truncated)
  metadata (hidden sm:flex): memory count + last activity (w-20 for alignment)
  dropdown actions (opacity-0 group-hover:opacity-100)
```

### Memory Card

Gem card component with hover shadow:

```
card (group hover:shadow-md)
  card/header layout: :row
    title + version badge (outline) + pinned badge (secondary)
    card/action (opacity-0 group-hover:opacity-100) → dropdown
  card/content
    prose preview (truncated 200 chars)
    tags row (flex-wrap gap-2, badge secondary with tag icon)
  card/footer
    timestamp (left) + "View Details" link button (right)
```

### Dashboard Stat Card

Clickable card linking to section:

```
card (hover:shadow-md)
  card/header → large icon (w-8 h-8 text-primary) + title + subtitle
  card/content → large number (text-2xl font-bold) + label
```

### Create Prompt Card

Dashed border card for "create new" CTAs:

```
card (border-dashed hover:shadow-md)
  card/content (flex-col items-center justify-center py-8)
    large icon (w-12 h-12 text-muted-foreground)
    title + description
```

## Forms

### Standard Form (Workspace)

Uses `data-component="form"` which applies `grid gap-6`:

```erb
<%= form_with model: resource, data: { component: "form" } do |form| %>
  <div data-form-part="group">
    <%= form.label :field, data: { component: "label" } %>
    <%= form.text_field :field, data: { component: "input" }, required: true, maxlength: 100, autocomplete: "off" %>
    <% if resource.errors[:field].any? %>
      <p data-form-part="error"><%= resource.errors[:field].first %></p>
    <% end %>
  </div>

  <div data-form-part="actions">
    <%= form.submit "Save", data: { component: "button", variant: "primary" } %>
    <%= link_to "Cancel", cancel_path, data: { component: "button", variant: "outline" } %>
  </div>
<% end %>
```

### Custom Editor Form (Memory)

Omits `data-component="form"` (documented with comment). Uses `local: true` to bypass Turbo. Layout:

```
Toolbar (shrink-0):  [title input, flex-1] [Cancel outline sm] [Save primary sm]
Metadata (shrink-0): [source 1/3, data-form-part="group"] [tags 2/3, data-form-part="group"]
Editor (flex-1):     bordered container with tab bar + write/preview panes
```

Error messages use `data-form-part="error" class="text-destructive"` (override needed because gem's `--destructive-foreground` is near-white).

### Tag Input

Custom component (`app/views/application/components/_tag_input.html.erb`) with Stimulus controller. Container uses `.tag-input-container` CSS class that mirrors the gem's input focus ring. Tags rendered as secondary-colored chips with X remove buttons. Hidden inputs generated for form submission.

### Auth Forms (Login/Password)

Use raw Tailwind classes (`grid gap-6 > grid gap-3` per field) and `btn-default`/`btn-ghost` CSS classes instead of data attributes.

## Alerts

Rendered via `render "components/alert"`. Always use the `icon:` parameter instead of placing icons inside the block.

| Use Case | Variant | Icon | Style |
|----------|---------|------|-------|
| Archived workspace | `:default` | `:archive` | Full, `mb-6` |
| Deleted workspace | `:warning` | `:trash_2` | Full, `mb-6`, includes days remaining |
| Editing non-latest version | `:warning` | `:info` | Compact, `py-2`, inline action link |
| Flash messages (security layout) | mapped from flash type | manual | Auto-dismiss 5s, manual close button |

## Empty States

Rendered via `render "components/empty"`.

| Context | Variant | Icon | Has Action? |
|---------|---------|------|-------------|
| No workspaces | `:outline` | `:folder_open` | "New Workspace" button |
| No archived workspaces | `:outline` | `:archive` | "Back to Workspaces" secondary button |
| No deleted workspaces | `:outline` | `:trash_2` | "Back to Workspaces" secondary button |
| No memories in workspace | `:outline` | `:sticky_note` | "Add First Memory" (only if active) |

## Dropdown Menus

### Trigger

Always `as_child: true` with a ghost icon button:

```erb
<%= render "components/dropdown_menu/trigger", as_child: true do %>
  <button type="button"
    data-component="button" data-variant="ghost" data-size="icon-sm"
    aria-label="Actions">
    <%= icon_for(:more_vertical, class: "w-4 h-4") %>
  </button>
<% end %>
```

### Content

```erb
<%= render "components/dropdown_menu/content", align: :end, css_classes: "w-48" do %>
  <%= render "components/dropdown_menu/item", href: path do %>
    <%= icon_for(:folder_open, class: "w-4 h-4") %> Open
  <% end %>
  <%= render "components/dropdown_menu/separator" %>
  <%= render "components/dropdown_menu/item", href: delete_path,
      css_classes: "text-destructive focus:text-destructive",
      data: { turbo_method: :delete, turbo_confirm: "Are you sure?" } do %>
    <%= icon_for(:trash_2, class: "w-4 h-4") %> Delete
  <% end %>
<% end %>
```

Destructive items use `css_classes: "text-destructive focus:text-destructive"` or `variant: :destructive`.

### Cleanup

Dropdown state is cleaned on `turbo:before-cache` and `turbo:before-render` in `application.js` to prevent stale open state on back/forward navigation.

## Badges

| Variant | Usage |
|---------|-------|
| `:outline` | Version labels (`v2`) |
| `:secondary` | Pinned indicator, tags (with `:tag` icon), root version |
| `:destructive` | "Deleted" status, days remaining countdown |
| `:warning` | "Archived" status |
| `:default` | Neutral/current version |

Tags pattern: `badge secondary text-xs` with `icon_for(:tag, class: "w-3 h-3")` + tag text.

## Buttons

### Via Data Attributes (Preferred)

```erb
data: { component: "button" }                              <%# primary (default) %>
data: { component: "button", variant: "primary" }          <%# explicit primary %>
data: { component: "button", variant: "outline" }          <%# bordered %>
data: { component: "button", variant: "secondary" }        <%# tinted %>
data: { component: "button", variant: "ghost" }            <%# transparent, hover bg %>
data: { component: "button", variant: "link" }             <%# text link style %>
data: { component: "button", variant: "destructive" }      <%# red %>
data: { component: "button", size: "sm" }                  <%# small %>
data: { component: "button", variant: "ghost", size: "icon-sm" }  <%# square icon %>
```

Works on `link_to`, `button_to`, `form.submit`, and raw `<button>` elements.

### Via CSS Classes (Auth Forms)

`btn-default`, `btn-ghost`, `btn-secondary`, `btn-outline`, `btn-destructive`, `btn-link`, `btn-sm`, `btn-lg`, `btn-icon`, `btn-icon-sm`.

## Pin Button

Shared partial `shared/_pin_button.html.erb`. Ghost icon-sm button with Turbo Stream.

- **Pinned**: pin icon rotated 45deg (`rotate-45`) in primary color (`text-primary`), DELETE action
- **Unpinned**: normal pin icon, POST action

## Tabs (Write/Preview)

Custom tab bar inside a bordered editor container:

```
div.shrink-0.flex.items-center.border-b.border-border.bg-muted/30.px-3 [role="tablist"]
  button [role="tab", data-state="active|inactive"]
    border-b-2 -mb-px  (pulls active indicator into parent border)
    data-[state=active]:border-primary data-[state=active]:text-foreground
    data-[state=inactive]:border-transparent data-[state=inactive]:text-muted-foreground
  span.ml-auto.text-xs.text-muted-foreground  ("Markdown" hint)
```

Panes toggle `hidden` class. Write pane has flush textarea (`.editor-textarea` CSS removes border/shadow). Preview pane uses Turbo Frame for server-rendered markdown.

## Metadata Display

### Horizontal Row

```erb
<div class="flex items-center gap-4 text-sm text-muted-foreground">
  <span class="inline-flex items-center gap-1">
    <%= icon_for(:clock, class: "w-4 h-4") %>
    Created <%= time_ago_in_words(resource.created_at) %> ago
  </span>
</div>
```

Icons at `w-4 h-4`. Each item is `inline-flex items-center gap-1`. Can mix badges inline.

### Card Footer

`text-xs text-muted-foreground` with `justify-between` for left timestamp / right action link.

### Responsive Metadata

`hidden sm:flex` hides metadata on mobile. Fixed-width `w-20` on time columns keeps lists aligned.

## Pagination

```erb
<div class="mt-6">
  <%= pagination_nav(pagy, :route_helper, params: { id: resource.id }) %>
</div>
```

## Breadcrumbs

```erb
<%= breadcrumbs({ "Workspaces" => workspaces_path }, "Current Page") %>
```

Workspace breadcrumbs adapt to state via `workspace_breadcrumb_links` helper -- inserts "Archived Workspaces" or "Deleted Workspaces" intermediate link based on workspace state. "Workspaces" is the top-level breadcrumb (Home/root is not included since it serves as the marketing page).

## Toasts

```erb
<%# Layout (automatic from flash) %>
<%= render "components/toaster", position: :bottom_right do %>
  <%= toast_flash_messages %>
<% end %>

<%# Manual toast %>
<%= render "components/toast", variant: :success, title: "Saved!", description: "Details." %>
```

Flash mapping: `notice`/`success` → `:success`, `alert`/`error` → `:error`, others → `:default`.

Variants: `:default`, `:success`, `:info`, `:warning`, `:error`. Note that `:info` exists for toasts but NOT for alerts.

## Confirm Dialog

Custom `<dialog>` element (`shared/_turbo_confirm_dialog.html.erb`) controlled by JavaScript override of `Turbo.config.forms.confirm`. Returns a Promise.

```
dialog#turbo-confirm (backdrop:bg-black/80)
  centered card (max-w-[425px], rounded-lg, border, shadow-lg)
    title: "Confirm Action"
    message: updated by JS from data-turbo-confirm attribute
    buttons: Cancel (btn-ghost) + Confirm (btn-default)
      mobile: flex-col-reverse (Confirm on top)
      tablet+: sm:flex-row sm:justify-end
```

Triggered by any element with `data: { turbo_confirm: "message" }`.

## Scroll-to-Top

Custom FAB button (not a gem component). Appears after 300px scroll on the closest `<main>` or window.

```
button.hidden.fixed.bottom-6.right-6.z-50.h-10.w-10.rounded-full
  .border.border-border.bg-background.text-primary.shadow-lg
  .hover:bg-muted.cursor-pointer
```

Stimulus controller implements `teardown()` to hide the button before Turbo cache.

## Prose / Markdown Content

Full-width rendered markdown:
```erb
<div class="prose max-w-none dark:prose-invert">
  <%= render_markdown(text) %>
</div>
```

Truncated preview in cards:
```erb
<div class="prose prose-sm max-w-none text-muted-foreground">
  <%= truncate(text, length: 200) %>
</div>
```

Uses `@tailwindcss/typography` plugin. Rendered via `Commonmarker` with smart quotes enabled.

## Icons

Rendered via `icon_for(:name, class: "size")`. Gem provides base icons; app provides 40+ SVG fallbacks in `MaquinaComponentsHelper#main_icon_svg_for`.

### Size Scale

| Context | Size |
|---------|------|
| Inside badges/tags | `w-3 h-3` |
| List item metadata | `w-3.5 h-3.5` |
| Buttons, menus, metadata | `w-4 h-4` |
| Scroll-to-top, headers | `w-5 h-5` or `size-5` |
| Dashboard card icons | `w-8 h-8` |
| Empty state illustrations | `w-12 h-12` |

### Commonly Used Icons

**Actions**: `plus`, `edit`, `trash_2`, `archive`, `archive_restore`, `rotate_ccw`, `copy_plus`
**Content**: `folder_open`, `folders`, `file_text`, `sticky_note`, `bookmark_plus`
**Navigation**: `arrow_left`, `chevron_right`, `chevron_down`, `chevron_up`
**Status**: `check_circle`, `info`, `alert_triangle`, `pin` (rotated 45deg when active), `tag`, `clock`
**UI**: `more_vertical`, `brain`, `gallery_vertical_end`, `log_out`

## Responsive Patterns

- **Container**: `mx-auto max-w-4xl` (all pages except editor)
- **Padding**: `p-4 md:p-6` (main area), `p-6 md:p-10` (security layout)
- **Grids**: `grid gap-4 md:grid-cols-2 lg:grid-cols-3` (dashboard)
- **Visibility**: `hidden sm:flex` (metadata in list items)
- **Button stacking**: `flex-col-reverse sm:flex-row sm:justify-end` (confirm dialog)
- **Container query**: `@container/main` on main wrapper (available for `@min-w` queries)

## Color Theme

Primary hue 150 (green) in oklch color space. Full light and dark mode support.

| Variable | Light | Dark | Usage |
|----------|-------|------|-------|
| `--primary` | `oklch(0.600 0.190 150)` | `oklch(0.580 0.180 150)` | Buttons, links, active tabs |
| `--destructive` | `oklch(0.580 0.237 28)` | same | Delete actions, error badges |
| `--warning` | `oklch(0.940 0.030 85)` | `oklch(0.250 0.025 85)` | Archived/deleted alerts |
| `--info` | `oklch(0.940 0.035 230)` | `oklch(0.250 0.030 230)` | Toast info variant |
| `--muted-foreground` | `oklch(0.460 0.010 150)` | `oklch(0.650 0.010 150)` | Metadata, placeholders |
