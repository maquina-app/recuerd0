import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["element"]

  connect() {
    this.boundHandleClickOutside = this.handleClickOutside.bind(this)
  }

  disconnect() {
    this.removeClickOutsideListener()
  }

  handleToggle(event) {
    const details = this.element

    if (details.open) {
      // Add click outside listener after a short delay to prevent immediate close
      setTimeout(() => {
        this.addClickOutsideListener()
      }, 100)
    } else {
      this.removeClickOutsideListener()
    }
  }

  handleClickOutside(event) {
    const details = this.element

    // Check if click is outside the details element
    if (!details.contains(event.target)) {
      this.closeWithAnimation()
    }
  }

  closeWithAnimation() {
    const details = this.element

    // Remove the open attribute to trigger CSS animation
    details.open = false

    // Clean up listener after animation
    this.removeClickOutsideListener()
  }

  addClickOutsideListener() {
    document.addEventListener("click", this.boundHandleClickOutside, true)
  }

  removeClickOutsideListener() {
    document.removeEventListener("click", this.boundHandleClickOutside, true)
  }
}
