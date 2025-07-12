import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    defaultOpen: { type: Boolean, default: true },
    cookieName: { type: String, default: "recuerd0_sidebar_state" },
    cookieMaxAge: { type: Number, default: 60 * 60 * 24 * 365 },
    keyboardShortcut: { type: String, default: "b" }
  }

  static outlets = ["sidebar"]

  connect() {
    // Set initial state from cookie or default
    const cookieValue = this.getCookie(this.cookieNameValue)
    const isOpen = cookieValue !== null ? cookieValue === "true" : this.defaultOpenValue

    if (this.hasSidebarOutlet) {
      this.sidebarOutlet.openValue = isOpen
    }

    // Setup keyboard shortcut
    this.keyboardHandler = this.handleKeyboard.bind(this)
    document.addEventListener("keydown", this.keyboardHandler)
  }

  disconnect() {
    document.removeEventListener("keydown", this.keyboardHandler)
  }

  toggle() {
    if (this.hasSidebarOutlet) {
      this.sidebarOutlet.toggle()
    }
  }

  // Called by sidebar outlet when state changes
  sidebarStateChanged(event) {
    const isOpen = event.detail.open
    this.setCookie(this.cookieNameValue, isOpen.toString(), this.cookieMaxAgeValue)

    // Also set data attribute on provider for CSS selectors
    this.element.setAttribute('data-sidebar-state', isOpen ? 'expanded' : 'collapsed')
  }

  handleKeyboard(event) {
    // Check for cmd+b (Mac) or ctrl+b (Windows/Linux)
    if ((event.metaKey || event.ctrlKey) && event.key === this.keyboardShortcutValue) {
      event.preventDefault()
      this.toggle()
    }
  }

  getCookie(name) {
    const value = `; ${document.cookie}`
    const parts = value.split(`; ${name}=`)
    if (parts.length === 2) return parts.pop().split(';').shift()
    return null
  }

  setCookie(name, value, maxAge) {
    document.cookie = `${name}=${value}; path=/; max-age=${maxAge}`
  }
}
