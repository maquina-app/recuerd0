import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// The ⌘K palette. The dialog itself lives in the layout as a sibling of the
// page content, so this controller is mounted on the header trigger and reaches
// into the dialog by id — Stimulus targets and actions would never bind across
// that boundary.
export default class extends Controller {
  static targets = ["shortcutHint"]
  static values = { searchUrl: String }

  static DEBOUNCE_MS = 200
  static MIN_QUERY_LENGTH = 3

  connect() {
    this.isMac = navigator.userAgentData
      ? /mac/i.test(navigator.userAgentData.platform)
      : /Mac|iPhone|iPad|iPod/.test(navigator.platform)
    const shortcutLabel = this.isMac ? "⌘K" : "Ctrl+K"

    // Guarded: without this, removing the desktop trigger would throw here and
    // silently kill the whole palette, ⌘K included.
    if (this.hasShortcutHintTarget) this.shortcutHintTarget.textContent = shortcutLabel

    this._dialog = document.getElementById("search-command-dialog")
    this._input = document.getElementById("search-command-input")
    this._scope = document.getElementById("search-command-scope")
    this._frame = document.getElementById("search_command_results")
    if (!this._dialog) return

    this.handleDialogClick = this.handleDialogClick.bind(this)
    this.handleFormSubmit = this.handleFormSubmit.bind(this)
    this.handleInputKeydown = this.handleInputKeydown.bind(this)
    this.handleInput = this.handleInput.bind(this)
    this.handleScopeToggle = this.handleScopeToggle.bind(this)
    this.handleMorph = this.handleMorph.bind(this)
    this.handleBeforeRender = this.handleBeforeRender.bind(this)
    this.handleFrameLoad = this.handleFrameLoad.bind(this)

    this._dialog.addEventListener("click", this.handleDialogClick)
    this._dialog.querySelector("form").addEventListener("submit", this.handleFormSubmit)
    this._input.addEventListener("keydown", this.handleInputKeydown)
    this._input.addEventListener("input", this.handleInput)
    this._scope?.addEventListener("click", this.handleScopeToggle)

    // A morph refresh pulls the dialog out of the top layer: `open` is not
    // serialised, so the palette silently vanishes mid-typing and the query is
    // stranded in a hidden input. Re-open and restore what was typed.
    document.addEventListener("turbo:before-render", this.handleBeforeRender)
    document.addEventListener("turbo:morph", this.handleMorph)
    this._frame?.addEventListener("turbo:frame-load", this.handleFrameLoad)
  }

  disconnect() {
    document.removeEventListener("turbo:before-render", this.handleBeforeRender)
    document.removeEventListener("turbo:morph", this.handleMorph)
    this._frame?.removeEventListener("turbo:frame-load", this.handleFrameLoad)
    clearTimeout(this._debounce)

    if (!this._dialog) return

    this._dialog.removeEventListener("click", this.handleDialogClick)
    this._dialog.querySelector("form")?.removeEventListener("submit", this.handleFormSubmit)
    this._input?.removeEventListener("keydown", this.handleInputKeydown)
    this._input?.removeEventListener("input", this.handleInput)
    this._scope?.removeEventListener("click", this.handleScopeToggle)
    this._dialog = null
    this._input = null
    this._scope = null
    this._frame = null
  }

  open(event) {
    // Both modifiers are bound in the markup because the action descriptor is
    // static, but on macOS Ctrl+K is readline's kill-to-end-of-line. Swallowing
    // it app-wide stole that from anyone typing in the memory editor.
    if (this.isMac && event.ctrlKey && !event.metaKey) return

    event.preventDefault()
    if (!this._dialog) return

    // Re-entrant ⌘K used to blank the field before re-showing an already-open
    // dialog, wiping whatever had been typed with no error.
    if (this._dialog.open) {
      this._input.focus()
      this._input.select()
      return
    }

    this._input.value = ""
    this.clearResults()
    this._dialog.showModal()
    this._input.focus()
  }

  // --- querying -----------------------------------------------------------

  handleInput() {
    clearTimeout(this._debounce)
    this._debounce = setTimeout(() => this.search(), this.constructor.DEBOUNCE_MS)
  }

  search() {
    if (!this._frame) return
    const query = this._input.value.trim()

    if (query.length < this.constructor.MIN_QUERY_LENGTH) {
      this.clearResults()
      return
    }

    this._frame.src = this.searchUrl(query)
  }

  searchUrl(query) {
    const url = new URL(this.searchUrlValue, window.location.origin)
    url.searchParams.set("q", query)
    if (this.scopedWorkspaceId) url.searchParams.set("workspace_id", this.scopedWorkspaceId)
    return url.toString()
  }

  get scopedWorkspaceId() {
    if (!this._scope || this._scope.getAttribute("aria-pressed") !== "true") return null
    return this._scope.dataset.workspaceId
  }

  handleScopeToggle(event) {
    event.preventDefault()
    const pressed = this._scope.getAttribute("aria-pressed") === "true"
    this._scope.setAttribute("aria-pressed", pressed ? "false" : "true")
    const label = this._scope.querySelector("[data-scope-label]")
    if (label) {
      label.textContent = pressed
        ? this._scope.dataset.scopeOff
        : this._scope.dataset.scopeOn
    }
    this.search()
    this._input.focus()
  }

  clearResults() {
    this._selected = null
    if (!this._frame) return
    this._frame.removeAttribute("src")
    this._frame.innerHTML = ""
    this._input?.setAttribute("aria-expanded", "false")
  }

  get results() {
    return Array.from(this._frame?.querySelectorAll("[data-palette-result]") || [])
  }

  // --- keyboard -----------------------------------------------------------

  handleInputKeydown(event) {
    // A search input captures Esc to clear itself, which would swallow the
    // native dialog close.
    if (event.key === "Escape") {
      event.preventDefault()
      this._dialog.close()
      return
    }

    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      const results = this.results
      if (results.length === 0) return
      event.preventDefault()
      const current = results.indexOf(this._selected)
      const next = event.key === "ArrowDown"
        ? (current + 1) % results.length
        : (current <= 0 ? results.length - 1 : current - 1)
      this.select(results[next])
    }
  }

  select(element) {
    this.results.forEach((el) => {
      el.setAttribute("aria-selected", "false")
      el.classList.remove("is-selected")
    })
    this._selected = element
    if (!element) return
    element.setAttribute("aria-selected", "true")
    element.classList.add("is-selected")
    element.scrollIntoView({ block: "nearest" })
    this._input?.setAttribute("aria-expanded", "true")
  }

  handleFormSubmit(event) {
    event.preventDefault()

    // Enter on a highlighted row opens that row; Enter with nothing highlighted
    // falls through to the full results page.
    if (this._selected && this.results.includes(this._selected)) {
      const href = this._selected.href
      this._dialog.close()
      Turbo.visit(href)
      return
    }

    const query = this._input.value.trim()
    if (query.length < this.constructor.MIN_QUERY_LENGTH) {
      // Closing on an unusable query used to look identical to a successful
      // search. Keep the palette open and let the hint do its job.
      this._input.focus()
      return
    }

    this._dialog.close()
    Turbo.visit(this.searchUrl(query))
  }

  // --- lifecycle ----------------------------------------------------------

  // Recorded before the render, because by the time turbo:morph fires the
  // dialog has already been dropped from the top layer and `open` is false.
  handleBeforeRender() {
    this._wasOpen = this._dialog?.open ? { value: this._input.value } : null
  }

  handleMorph() {
    if (!this._dialog || this._dialog.open || !this._wasOpen) return
    const { value } = this._wasOpen
    this._wasOpen = null
    this._dialog.showModal()
    this._input.value = value
    this._input.focus()
    this.search()
  }

  // Rows are replaced wholesale on each query, so any previously highlighted
  // node is detached and must not stay selected.
  handleFrameLoad() {
    this._selected = null
    this._input?.setAttribute("aria-expanded", this.results.length > 0 ? "true" : "false")
  }

  handleDialogClick(event) {
    if (!event.target.closest("[data-search-command-panel]")) {
      this._dialog.close()
    }
  }

  teardown() {
    if (this._dialog?.open) {
      this._dialog.close()
    }
    if (this._input) {
      this._input.value = ""
    }
  }
}
