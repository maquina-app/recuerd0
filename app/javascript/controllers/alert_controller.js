import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="alert"
export default class extends Controller {
  static values = {
    dismissAfter: { type: Number, default: 5000 },
    removeAfter: { type: Number, default: 300 }
  }

  connect() {
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

    // Add fade-out animation
    this.element.style.transition = `opacity ${this.removeAfterValue}ms ease-out`
    this.element.style.opacity = "0"

    // Remove element after animation completes
    setTimeout(() => {
      this.element.remove()
    }, this.removeAfterValue)
  }
}
