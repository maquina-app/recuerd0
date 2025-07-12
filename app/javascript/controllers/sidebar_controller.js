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

  connect() {
    // Check if this is mobile or desktop sidebar
    this.mobileValue = this.sidebarTarget.getAttribute("data-mobile") === "true"

    if (!this.mobileValue) {
      // Only setup resize handler for desktop
      this.checkMobile()
      this.resizeHandler = this.checkMobile.bind(this)
      window.addEventListener("resize", this.resizeHandler)
    }

    // Set initial state based on open value
    this.updateState()
  }

  disconnect() {
    if (this.resizeHandler) {
      window.removeEventListener("resize", this.resizeHandler)
    }
  }

  openValueChanged() {
    this.updateState()

    // Dispatch a custom event that the provider can listen to
    this.dispatch("stateChanged", {
      detail: { open: this.openValue },
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
    const isMobile = this.mobileValue
    const isOpen = this.openValue
    const collapsible = this.collapsibleValue

    // Update sidebar state
    if (this.hasSidebarTarget) {
      const sidebar = this.sidebarTarget

      // Set data attributes for CSS
      sidebar.setAttribute("data-state", isOpen ? "expanded" : "collapsed")
      sidebar.setAttribute("data-collapsible", collapsible)

      // Handle mobile specific states
      if (isMobile) {
        if (collapsible === "offcanvas") {
          // On mobile, sidebar slides in/out
          if (isOpen) {
            // Remove translate classes to show sidebar
            if (this.sideValue === "left") {
              sidebar.classList.remove("-translate-x-full")
              sidebar.classList.add("translate-x-0")
            } else {
              sidebar.classList.remove("translate-x-full")
              sidebar.classList.add("-translate-x-0")
            }
            // Show backdrop
            if (this.hasBackdropTarget) {
              this.backdropTarget.classList.remove("hidden")
            }
          } else {
            // Add translate classes to hide sidebar
            if (this.sideValue === "left") {
              sidebar.classList.add("-translate-x-full")
              sidebar.classList.remove("translate-x-0")
            } else {
              sidebar.classList.add("translate-x-full")
              sidebar.classList.remove("-translate-x-0")
            }
            // Hide backdrop
            if (this.hasBackdropTarget) {
              this.backdropTarget.classList.add("hidden")
            }
          }
        }
      } else {
        // Desktop sidebar doesn't use translate classes
        sidebar.classList.remove("-translate-x-full", "translate-x-full", "translate-x-0", "-translate-x-0")
        // Always hide backdrop on desktop
        if (this.hasBackdropTarget) {
          this.backdropTarget.classList.add("hidden")
        }
      }

      // Update the sidebar trigger icon if present
      const trigger = document.querySelector('[data-slot="sidebar-trigger"] .sidebar-trigger-icon svg')
      if (trigger && !isMobile) {
        if (isOpen) {
          trigger.classList.remove("lucide-panel-left-close")
          trigger.classList.add("lucide-panel-left-open")
        } else {
          trigger.classList.remove("lucide-panel-left-open")
          trigger.classList.add("lucide-panel-left-close")
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
