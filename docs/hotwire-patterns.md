# Hotwire Patterns

How Recuerd0 uses Turbo Drive, Turbo Frames, and Stimulus. This document supplements `CLAUDE.md` with deeper rationale and implementation details.

---

## Turbo Drive

### Setup

Turbo is loaded via importmap (`@hotwired/turbo-rails`) in `app/javascript/application.js`. Every navigation and form submission goes through Turbo Drive by default — no opt-in needed.

Stylesheets use `data-turbo-track: "reload"` so Turbo performs a full page reload when the asset fingerprint changes after deployment:

```erb
<%= stylesheet_link_tag :tailwind, "data-turbo-track": "reload" %>
```

### Page Morphing (Turbo 8)

The layout declares morph mode globally:

```erb
<%# app/views/layouts/application.html.erb %>
<%= turbo_refresh_method_tag :morph %>
<%= turbo_refresh_scroll_tag :preserve %>
```

**What this does:** When Turbo follows a redirect back to the same page, it diffs the new `<body>` against the current DOM using idiomorph and patches only the elements that changed. `:preserve` keeps the scroll position across morphs.

**When morph activates:** Turbo morphs instead of replacing when the response URL matches the current URL. This happens naturally with redirect-back-to-same-page (e.g., `redirect_to profile_path` after updating the profile).

### Form Submissions and 303 Redirects

Rails convention for Turbo form submissions:

1. **Success:** `redirect_to resource_path` — Rails returns 303 See Other, Turbo follows and morphs.
2. **Validation failure:** `render :show, status: :unprocessable_entity` — Turbo replaces the page so error messages appear.

```ruby
# app/controllers/profiles_controller.rb
def update
  if @user.update(profile_params)
    redirect_to profile_path, notice: t(".updated")   # 303 → morph
  else
    render :show, status: :unprocessable_entity        # 422 → replace
  end
end
```

**The 303 status is critical.** Turbo Drive only follows redirects that respond with 303 for non-GET requests. `redirect_to` in Rails produces 303 by default for PATCH/POST/DELETE, so no explicit `status: :see_other` is needed.

### Morph vs. Turbo Stream Refresh

`turbo_stream.refresh` is **not** a replacement for `redirect_to` in form responses. It is designed for WebSocket broadcasting (Action Cable) to tell all connected clients to re-fetch and morph the page. When returned as a direct form response, the `request_id` embedded in the refresh action matches the requesting page's own ID, causing Turbo to silently deduplicate and skip the refresh.

| Technique | Use case |
|-----------|----------|
| `redirect_to same_path` | Form submissions — morph via 303 redirect |
| `turbo_stream.refresh` | Broadcasting — tell other clients to refresh |

### Opting Out of Turbo Drive

Use `local: true` on a form to bypass Turbo Drive entirely. The memory editor form does this because the Stimulus `markdown-editor` controller and its preview sub-form need a standard full-page navigation lifecycle for reliable teardown and reinitialization:

```erb
<%# app/views/memories/_form.html.erb %>
<%= form_with model: [workspace, memory], local: true, ... do |form| %>
```

### Excluding Elements from Morph

Use `data-turbo-permanent` to exclude an element from morphing during page refreshes. The element must have a unique `id`. Turbo will preserve the original element and its children untouched:

```html
<div id="player" data-turbo-permanent>
  <!-- Audio/video player state preserved across morphs -->
</div>
```

This app does not currently use `data-turbo-permanent`, but it's available for future features that need to preserve complex client-side state (e.g., media players, map widgets) during page refreshes.

### Prefetching

Turbo Drive prefetches links on hover by default (since Turbo 8). No additional configuration needed. This gives sub-100ms perceived page loads on fast networks. Prefetching can be disabled per-element with `data-turbo-prefetch="false"` or globally via `<meta name="turbo-prefetch" content="false">`.

### Asset Tracking

The `data-turbo-track="reload"` attribute on stylesheets and scripts tells Turbo to compare the asset URL on each navigation. If the fingerprint changes (e.g., after a deployment), Turbo forces a full page reload instead of trying to merge new CSS/JS on top of the old:

```erb
<%= stylesheet_link_tag :tailwind, "data-turbo-track": "reload" %>
<%= javascript_importmap_tags %> <%# also produces tracked script tags %>
```

### Submit Button Feedback

Turbo automatically disables the form submitter during submission. For additional UX, `data-turbo-submits-with` replaces the button text while the request is in flight:

```erb
<%= form.submit "Save", data: { turbo_submits_with: "Saving..." } %>
```

This attribute is not currently used in the app but is available for forms where network latency warrants visual feedback beyond the default disabled state.

### View Transitions

Turbo supports the [View Transition API](https://developer.mozilla.org/en-US/docs/Web/API/View_Transitions_API) for animated page transitions. Enable by adding to both pages:

```html
<meta name="view-transition" content="same-origin">
```

Turbo adds `data-turbo-visit-direction` (`forward`, `back`, `none`) to `<html>` for directional CSS animations. Not currently used in the app.

---

## Turbo Frames

Turbo Frames scope navigation and updates to a region of the page. In Recuerd0, they are used for the markdown preview.

### Markdown Preview

The memory editor has a hidden form that submits content to a preview endpoint. Both the form and the response are scoped to the `markdown_preview` frame:

```erb
<%# In the editor — write pane sibling %>
<%= turbo_frame_tag "markdown_preview" do %>
  <p class="text-sm text-muted-foreground italic">Click Preview to render</p>
<% end %>

<%# Hidden form targeting the frame %>
<%= form_with url: preview_workspace_memories_path(workspace),
    data: { turbo_frame: "markdown_preview", ... }, class: "hidden" do |f| %>
  <%= f.hidden_field :content, value: "" %>
<% end %>
```

The server response wraps the rendered HTML in the same frame tag:

```erb
<%# app/views/memories/previews/create.html.erb %>
<%= turbo_frame_tag "markdown_preview" do %>
  <div class="prose max-w-none dark:prose-invert">
    <%= render_markdown(@content) %>
  </div>
<% end %>
```

The Stimulus `markdown-editor` controller copies the textarea content into the hidden field and submits the form programmatically:

```javascript
showPreview() {
  this.contentInputTarget.value = this.textareaTarget.value
  this.previewFormTarget.requestSubmit()
}
```

**Key point:** Only the content inside `<turbo-frame id="markdown_preview">` gets replaced. The rest of the page (title input, tag input, toolbar) is untouched.

### Frame Events

Turbo Frames emit their own navigation events on the `<turbo-frame>` element:

| Event | When |
|-------|------|
| `turbo:before-frame-render` | Before rendering the new frame content. Cancel to prevent, or override `event.detail.render` |
| `turbo:frame-render` | After the frame content is rendered |
| `turbo:frame-load` | After the frame finishes loading |
| `turbo:frame-missing` | When the response doesn't contain a matching frame |

The `turbo:frame-missing` event is useful for error handling — if the server response doesn't include the expected `<turbo-frame>` tag, Turbo writes an error message into the frame by default.

---

## Turbo Event Lifecycle

Turbo dispatches events at each stage of navigation, form submission, and rendering. The most relevant events for this app:

### Navigation events (on `document.documentElement`)

| Event | Purpose |
|-------|---------|
| `turbo:click` | Link clicked — cancel to fall through to browser |
| `turbo:before-visit` | Before navigating — cancel to prevent |
| `turbo:visit` | Visit started — access `event.detail.url` and `event.detail.action` |
| `turbo:before-cache` | Before snapshotting DOM for cache |
| `turbo:before-render` | Before painting response — access `event.detail.newBody` |
| `turbo:render` | After rendering — `event.detail.renderMethod` is `"replace"` or `"morph"` |
| `turbo:load` | Page fully loaded (fires on initial load and every visit) |

### Form events (on the `<form>` element, bubble up)

| Event | Purpose |
|-------|---------|
| `turbo:submit-start` | Submission begins — submitter gets `disabled`. Call `event.detail.formSubmission.stop()` to abort |
| `turbo:submit-end` | Network request complete — check `event.detail.success` |

### Morph events (on the morphed element)

| Event | Purpose |
|-------|---------|
| `turbo:before-morph-element` | Before morphing a specific element — cancel to skip |
| `turbo:before-morph-attribute` | Before changing an attribute — cancel to preserve |
| `turbo:morph-element` | After an element is morphed |
| `turbo:morph` | After the entire page morph completes |

### Events used in this app

- **`turbo:before-cache`** — Global teardown of Stimulus controllers + dropdown cleanup
- **`turbo:before-render`** — Dropdown cleanup on `event.detail.newBody` for back/forward navigation

---

## Turbo Cache and DOM Cleanup

Turbo Drive caches page snapshots for instant back/forward navigation. This creates a problem: stateful DOM (open dropdowns, active preview tabs, visible FABs) gets frozen into the cache and flashes briefly when the snapshot is restored.

### Two cleanup events

| Event | Fires when | Target |
|-------|-----------|--------|
| `turbo:before-cache` | Navigating away — before snapshotting the live DOM | `document` |
| `turbo:before-render` | Back/Forward — before painting a cached snapshot | `event.detail.newBody` |

Both events need cleanup handlers. `before-cache` prevents stale state from entering the cache. `before-render` catches cases where the cache already contains stale state (e.g., from a previous visit).

### Global teardown pattern

`app/javascript/controllers/application.js` implements the [Better Stimulus teardown pattern](https://www.betterstimulus.com/turbo/teardown.html). Before Turbo caches the page, it calls `teardown()` on every connected Stimulus controller that defines the method:

```javascript
document.addEventListener("turbo:before-cache", () => {
  application.controllers.forEach((controller) => {
    if (typeof controller.teardown === "function") {
      controller.teardown()
    }
  })
})
```

Controllers implement `teardown()` to reset visual state:

```javascript
// clipboard_controller.js
teardown() {
  clearTimeout(this.feedbackTimeout)
  this.copyIconTarget.classList.remove("hidden")
  this.checkIconTarget.classList.add("hidden")
}

// markdown_editor_controller.js
teardown() {
  this.modeValue = "write"
  this.syncTabs()
}

// scroll_to_top_controller.js
teardown() {
  this.buttonTarget.classList.add("hidden")
}
```

### Gem dropdown cleanup

The `maquina-components` gem's dropdown menus don't have a `teardown()` method yet. Manual cleanup in `application.js` resets all open dropdowns on both cache events:

```javascript
function closeOpenDropdowns(root) {
  root.querySelectorAll('[data-controller="dropdown-menu"][data-state="open"]')
    .forEach((dropdown) => {
      dropdown.setAttribute("data-state", "closed")
      // ... reset content, trigger, aria-expanded
    })
}

document.addEventListener("turbo:before-cache", () => closeOpenDropdowns(document))
document.addEventListener("turbo:before-render", (event) => {
  closeOpenDropdowns(event.detail.newBody)
})
```

### Why `data-turbo-temporary` doesn't work with morph

Turbo's `data-turbo-temporary` attribute removes elements from the cached snapshot. However, when morph mode is active, Turbo uses idiomorph to diff and patch rather than restoring from cache — so `data-turbo-temporary` has no effect. Use the teardown pattern instead.

---

## Custom Confirm Dialog

Turbo provides a hook to replace the browser's native `confirm()` dialog. Recuerd0 overrides it with a styled `<dialog>` element that matches the app's design system.

### Setup

A `<dialog>` element is rendered in the layout (`app/views/shared/_turbo_confirm_dialog.html.erb`). On `DOMContentLoaded`, the override is registered:

```javascript
Turbo.config.forms.confirm = (message, element) => {
  // ... show dialog, return Promise<boolean>
}
```

### How it works

1. Turbo calls the function with the `data-turbo-confirm` message and the element.
2. The function updates the dialog's message text and calls `dialog.showModal()`.
3. It returns a `Promise` that resolves `true` (confirm) or `false` (cancel).
4. Turbo waits for the promise — if `true`, the form submits; if `false`, it's cancelled.
5. ESC key triggers the `cancel` event on the dialog, which resolves `false`.

### Usage in views

Any form or link with `data-turbo-confirm` triggers the custom dialog:

```erb
<%= button_to "Delete", resource_path(resource),
    method: :delete,
    data: { turbo_confirm: "Are you sure you want to delete this?" } %>
```

---

## Stimulus Controllers

All controllers are in `app/javascript/controllers/` and auto-registered via importmap's `pin_all_from` and `stimulus-loading`.

### Controller inventory

| Controller | Purpose | Teardown? |
|-----------|---------|-----------|
| `clipboard` | Copy text to clipboard, select input content | Yes |
| `details` | Close `<details>` on outside click | No |
| `markdown-editor` | Write/Preview tab switching with preview form submission | Yes |
| `navigate` | Navigate on `<select>` change via `Turbo.visit` | No |
| `scroll-to-top` | FAB button appears at 300px scroll, smooth scroll to top | Yes |
| `search-form` | Clear search navigates to base URL without params | No |
| `tag-input` | Add/remove tags with Enter/comma/Backspace, hidden inputs | No |

### Patterns used

**Targets** — Named element references. Declared with `static targets = [...]`, accessed as `this.nameTarget`:

```javascript
static targets = ["source", "copyIcon", "checkIcon"]
// this.sourceTarget, this.copyIconTarget, this.checkIconTarget
```

**Values** — Reactive properties backed by `data-*-value` attributes. Changes trigger `{name}ValueChanged` callbacks:

```javascript
static values = { mode: { type: String, default: "write" } }
// this.modeValue — reads/writes "write" or "preview"
```

**Actions** — Event-to-method bindings declared in HTML:

```html
<button data-action="click->clipboard#copy">Copy</button>
<input data-action="keydown->tag-input#handleKeydown">
<select data-action="change->navigate#visit">
```

**Lifecycle** — `connect()` runs when the element enters the DOM, `disconnect()` when it leaves. Use `connect()` for setup (event listeners, initial state) and `disconnect()` for cleanup:

```javascript
// details_controller.js
connect() {
  this.boundHandleClickOutside = this.handleClickOutside.bind(this)
}
disconnect() {
  this.removeClickOutsideListener()
}
```

**Teardown** — App-specific convention for Turbo cache cleanup. Not a Stimulus lifecycle method — called by the global teardown handler in `application.js`:

```javascript
teardown() {
  // Reset visual state so the cached snapshot is clean
  this.buttonTarget.classList.add("hidden")
}
```

### When to add teardown

Add `teardown()` when the controller modifies DOM state that should not persist in the Turbo cache:

- **Toggled visibility** (FAB button, icons, tabs) — reset to default state
- **Timers** — clear pending timeouts
- **CSS classes added dynamically** — remove them

Do **not** add `teardown()` for controllers that only read DOM or navigate — they have no stale state to clean up.

### XSS prevention in dynamic HTML

The `tag-input` controller creates DOM elements dynamically. It uses `textContent` assignment for escaping:

```javascript
escapeHtml(text) {
  const div = document.createElement("div")
  div.textContent = text
  return div.innerHTML
}
```

This prevents XSS when user-supplied tag names are rendered into badge HTML.

---

## Data Attributes Quick Reference

Turbo data attributes used or available in this app:

| Attribute | Purpose | Used? |
|-----------|---------|-------|
| `data-turbo="false"` | Disable Turbo on element and descendants | No (use `local: true` on forms instead) |
| `data-turbo-track="reload"` | Force full reload when asset changes | Yes — on stylesheet link tag |
| `data-turbo-frame="id"` | Target a specific Turbo Frame | Yes — markdown preview form |
| `data-turbo-confirm="msg"` | Show confirm dialog before action | Yes — delete buttons |
| `data-turbo-method="delete"` | Change link request method | Yes — via `button_to` |
| `data-turbo-permanent` | Exclude from morph, preserve across navigations | Available |
| `data-turbo-temporary` | Remove before caching (no effect with morph) | Not used — see teardown pattern |
| `data-turbo-action="replace"` | Replace history entry instead of pushing | Available |
| `data-turbo-prefetch="false"` | Disable hover prefetching per-element | Available |
| `data-turbo-submits-with="..."` | Replace button text during submission | Available |
| `data-turbo-stream` | Accept Turbo Stream responses on GET | Not used |

### Meta tags

| Meta tag | Value | Used? |
|----------|-------|-------|
| `turbo-refresh-method` | `morph` | Yes — layout |
| `turbo-refresh-scroll` | `preserve` | Yes — layout |
| `turbo-cache-control` | `no-cache` / `no-preview` | Available |
| `turbo-visit-control` | `reload` | Available |
| `turbo-prefetch` | `false` | Available |
| `view-transition` | `same-origin` | Available |

---

## Common Pitfalls

1. **Using `turbo_stream.refresh` as a form response** — It will be silently ignored due to request_id deduplication. Use `redirect_to` instead.

2. **Forgetting 303 on non-GET** — `redirect_to` handles this automatically in Rails, but if you build custom responses, Turbo won't follow redirects without 303 status.

3. **Rendering 200 on POST** — Turbo won't update the URL for a 200 response to a POST. It stays on the current URL to avoid the browser's "resubmit form?" dialog on reload. Only 4xx/5xx responses render in place; success must redirect.

4. **Stale cached state with morph** — `data-turbo-temporary` doesn't work with morph mode. Use the `teardown()` pattern for Stimulus controllers or manual cleanup on `turbo:before-cache`.

5. **Nested forms for Turbo Frames** — HTML doesn't allow nested `<form>` elements. The markdown editor solves this by placing the preview form as a sibling, linked to the frame via `data-turbo-frame`.

6. **Missing Turbo Frame in response** — If the server response doesn't contain a matching `<turbo-frame>` tag, Turbo writes an error into the frame and throws an exception. Handle with `turbo:frame-missing` event or ensure all frame responses include the expected frame tag.

7. **Lazy I18n inside gem partials** — When yielding blocks to gem components, `t(".key")` resolves to the gem's partial path, not your app's. Use fully-qualified keys inside `do...end` blocks for gem-rendered partials.

8. **URLs with dots** — Turbo ignores paths with a `.` in the last segment (e.g., `/messages.67`) unless the extension is `.htm`, `.html`, `.xhtml`, or `.php`. Append `/` to force Turbo handling if needed.
