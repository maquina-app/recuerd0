import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="alert"
export default class extends Controller {
  static values = {
    dismissAfter: { type: Number, default: 5000 },
    removeAfter: { type: Number, default: 300 }
  }

  connect() {
    // Add enter animation
    this.element.style.animation = "slide-in-from-right 300ms cubic-bezier(0.16, 1, 0.3, 1), fade-in 300ms cubic-bezier(0.16, 1, 0.3, 1)"

    // Auto-dismiss after specified time
    if (this.dismissAfterValue > 0) {
      this.dismissTimeout = setTimeout(() => {
        this.dismiss()
      }, this.dismissAfterValue)
    }
  }

  disconnect() {
    // Clear timeout if element is removed before auto-dismiss
    if (this.dismissTimeout) {
      clearTimeout(this.dismissTimeout)
    }
  }

  dismiss() {
    // Clear the timeout
    if (this.dismissTimeout) {
      clearTimeout(this.dismissTimeout)
    }

    // Add exit animation
    this.element.style.animation = "slide-out-to-right 300ms cubic-bezier(0.4, 0, 1, 1), fade-out 300ms cubic-bezier(0.4, 0, 1, 1)"

    // Remove element after animation completes
    setTimeout(() => {
      this.element.remove()
    }, this.removeAfterValue)
  }
}
