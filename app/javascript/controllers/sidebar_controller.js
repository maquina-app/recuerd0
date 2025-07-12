import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    open: { type: Boolean, default: true },
    mobile: { type: Boolean, default: false },
    collapsible: { type: String, default: "offcanvas" },
    side: { type: String, default: "left" },
    variant: { type: String, default: "sidebar" }
  }

  static targets = ["sidebar", "backdrop"]

  static outlets = ["sidebar-provider"]

  connect() {
    this.checkMobile()
    this.resizeHandler = this.checkMobile.bind(this)
    window.addEventListener("resize", this.resizeHandler)

    // Set initial state based on open value
    this.updateState()
  }

  disconnect() {
    window.removeEventListener("resize", this.resizeHandler)
  }

  openValueChanged() {
    this.updateState()

    // Notify provider of state change
    if (this.hasSidebarProviderOutlet) {
      this.dispatch("stateChanged", { detail: { open: this.openValue } })
    }
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
    const isMobile = this.mobileValue
    const isOpen = this.openValue
    const collapsible = this.collapsibleValue

    // Update sidebar state
    if (this.hasSidebarTarget) {
      const sidebar = this.sidebarTarget

      // Set data attributes for CSS
      sidebar.setAttribute("data-state", isOpen ? "expanded" : "collapsed")
      sidebar.setAttribute("data-collapsible", collapsible)
      sidebar.setAttribute("data-variant", this.variantValue)
      sidebar.setAttribute("data-side", this.sideValue)

      // Handle mobile specific states
      if (isMobile) {
        sidebar.setAttribute("data-mobile", "true")
        if (collapsible === "offcanvas") {
          // On mobile, sidebar slides in/out
          if (isOpen) {
            sidebar.classList.remove("-translate-x-full")
            sidebar.classList.add("translate-x-0")
            // Show backdrop
            if (this.hasBackdropTarget) {
              this.backdropTarget.classList.remove("hidden")
              this.backdropTarget.classList.add("block")
            }
          } else {
            sidebar.classList.add("-translate-x-full")
            sidebar.classList.remove("translate-x-0")
            // Hide backdrop
            if (this.hasBackdropTarget) {
              this.backdropTarget.classList.add("hidden")
              this.backdropTarget.classList.remove("block")
            }
          }
        }
      } else {
        sidebar.setAttribute("data-mobile", "false")
        sidebar.classList.remove("-translate-x-full", "translate-x-0")
        // Always hide backdrop on desktop
        if (this.hasBackdropTarget) {
          this.backdropTarget.classList.add("hidden")
        }
      }
    }
  }

  checkMobile() {
    const wasMobile = this.mobileValue
    this.mobileValue = window.innerWidth < 768

    // If switching from mobile to desktop, ensure sidebar is visible
    if (wasMobile && !this.mobileValue && !this.openValue) {
      this.openValue = true
    }
  }

  backdropClick() {
    if (this.mobileValue && this.openValue) {
      this.close()
    }
  }
}
