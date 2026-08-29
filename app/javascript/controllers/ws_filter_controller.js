import { Controller } from "@hotwired/stimulus"

// Debounced submit into the workspaces list frame. The filtering itself happens
// on the server, so it searches the whole account rather than the page you
// happen to be on — the previous DOM-only version was wrong for any account
// with more workspaces than fit on one page.
export default class extends Controller {
  static targets = ["input", "form"]
  static values = { delay: { type: Number, default: 250 } }

  connect() {
    this.handleShortcut = this.handleShortcut.bind(this)
    document.addEventListener("keydown", this.handleShortcut)
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleShortcut)
    clearTimeout(this._timer)
  }

  // "/" focuses the filter, the way it does in most developer tools — but not
  // while the visitor is typing somewhere else, and not while a menu or dialog
  // has taken over the keyboard.
  handleShortcut(event) {
    if (event.key !== "/" || event.metaKey || event.ctrlKey || event.altKey) return
    if (document.querySelector("dialog[open]")) return
    if (document.querySelector('[data-dropdown-menu-part="content"][data-state="open"]')) return

    const active = document.activeElement
    if (active && (active.isContentEditable || /^(INPUT|TEXTAREA|SELECT)$/.test(active.tagName))) return

    event.preventDefault()
    this.inputTarget.focus()
    this.inputTarget.select()
  }

  submit() {
    clearTimeout(this._timer)
    this._timer = setTimeout(() => this.formTarget.requestSubmit(), this.delayValue)
  }

  clear(event) {
    event?.preventDefault()
    if (this.inputTarget.value === "") {
      this.inputTarget.blur()
      return
    }
    this.inputTarget.value = ""
    clearTimeout(this._timer)
    this.formTarget.requestSubmit()
  }

  teardown() {
    clearTimeout(this._timer)
  }
}
