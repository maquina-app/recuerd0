import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    open: { type: Boolean, default: true },
    collapsible: { type: String, default: "offcanvas" },
    side: { type: String, default: "left" },
    variant: { type: String, default: "sidebar" }
  }

  static targets = ["sidebar", "backdrop"]

  connect() {
    // Check if we're on mobile initially
    this.checkScreenSize()

    // Setup resize handler
    this.resizeHandler = this.checkScreenSize.bind(this)
    window.addEventListener("resize", this.resizeHandler)

    // Set initial state based on open value - no need to delay
    this.updateState()
  }

  disconnect() {
    window.removeEventListener("resize", this.resizeHandler)
  }

  openValueChanged() {
    this.updateState()

    // Dispatch a custom event that the provider can listen to
    this.dispatch("stateChanged", {
      detail: { open: this.openValue, mobile: this.isMobile() },
      bubbles: true
    })
  }

  toggle() {
    this.openValue = !this.openValue
  }

  open() {
    this.openValue = true
  }

  close() {
    this.openValue = false
  }

  updateState() {
    const isOpen = this.openValue
    const isMobile = this.isMobile()

    // Update sidebar state
    if (this.hasSidebarTarget) {
      const sidebar = this.sidebarTarget
      sidebar.setAttribute("data-state", isOpen ? "expanded" : "collapsed")

      // Update backdrop state - only change the data-state attribute
      if (this.hasBackdropTarget) {
        const newBackdropState = (isOpen && isMobile) ? "expanded" : "collapsed"
        this.backdropTarget.setAttribute("data-state", newBackdropState)
      }
    }
  }

  checkScreenSize() {
    const wasMobile = this._isMobile
    this._isMobile = window.innerWidth < 768

    // If switching from mobile to desktop, ensure sidebar is open
    if (wasMobile && !this._isMobile && !this.openValue) {
      this.openValue = true
    }

    // If switching from desktop to mobile, close sidebar
    if (!wasMobile && this._isMobile && this.openValue) {
      this.openValue = false
    }

    // Update state when screen size changes
    if (wasMobile !== this._isMobile) {
      this.updateState()
    }
  }

  isMobile() {
    return window.innerWidth < 768
  }

  backdropClick() {
    if (this.isMobile() && this.openValue) {
      this.close()
    }
  }
}
