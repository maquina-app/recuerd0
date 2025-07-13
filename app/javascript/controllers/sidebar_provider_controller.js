import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    defaultOpen: { type: Boolean, default: true },
    cookieName: { type: String, default: "recuerd0_sidebar_state" },
    cookieMaxAge: { type: Number, default: 60 * 60 * 24 * 365 },
    keyboardShortcut: { type: String, default: "b" }
  }

  static outlets = ["sidebar"]

  initialize() {
    // Set initial state from cookie or default
    const cookieValue = this.getCookie(this.cookieNameValue)
    const isOpen = cookieValue !== null ? cookieValue === "true" : this.defaultOpenValue

    // Store the desired open state to apply when outlets connect
    this.desiredOpenState = isOpen

    // Apply state to data attribute immediately
    this.element.setAttribute('data-sidebar-state', isOpen ? 'expanded' : 'collapsed')
  }

  connect() {
    // Setup keyboard shortcut
    this.keyboardHandler = this.handleKeyboard.bind(this)
    document.addEventListener("keydown", this.keyboardHandler)

    // Listen for state changes from sidebar controllers
    this.element.addEventListener("sidebar:stateChanged", this.handleSidebarStateChanged.bind(this))
  }

  disconnect() {
    document.removeEventListener("keydown", this.keyboardHandler)
    this.element.removeEventListener("sidebar:stateChanged", this.handleSidebarStateChanged.bind(this))
  }

  // Called when a sidebar outlet is connected
  sidebarOutletConnected(outlet, element) {
    // Set initial state when outlet connects
    // On mobile, always start closed; on desktop, use saved state
    const isMobile = window.innerWidth < 768
    const targetState = isMobile ? false : this.desiredOpenState

    // Update the sidebar's state without triggering animations on initial load
    if (outlet.openValue !== targetState) {
      // Temporarily disable transitions
      const sidebar = outlet.sidebarTarget
      const originalTransition = sidebar.style.transition
      sidebar.style.transition = 'none'

      // Set the state
      outlet.openValue = targetState

      // Re-enable transitions after a frame
      requestAnimationFrame(() => {
        sidebar.style.transition = originalTransition
      })
    }
  }

  toggle() {
    if (this.hasSidebarOutlet) {
      this.sidebarOutlets.forEach(outlet => {
        outlet.toggle()
      })
    }
  }

  // Handle state changes from sidebar controllers
  handleSidebarStateChanged(event) {
    const isOpen = event.detail.open
    const isMobile = event.detail.mobile

    // Only save cookie for desktop sidebar state
    if (!isMobile) {
      this.setCookie(this.cookieNameValue, isOpen.toString(), this.cookieMaxAgeValue)
      this.desiredOpenState = isOpen

      // Also set data attribute on provider for CSS selectors
      this.element.setAttribute('data-sidebar-state', isOpen ? 'expanded' : 'collapsed')
    }
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
    document.cookie = `${name}=${value}; path=/; max-age=${maxAge}; SameSite=Lax`
  }
}
