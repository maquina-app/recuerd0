import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["trigger", "content"]
  static values = {
    open: { type: Boolean, default: false },
    side: { type: String, default: "bottom" },
    align: { type: String, default: "center" },
    sideOffset: { type: Number, default: 4 }
  }

  connect() {
    this.clickOutsideHandler = this.clickOutside.bind(this)
    this.keydownHandler = this.handleKeydown.bind(this)
  }

  disconnect() {
    this.close()
  }

  toggle(event) {
    event.stopPropagation()
    this.openValue = !this.openValue
  }

  open() {
    this.openValue = true
  }

  close() {
    this.openValue = false
  }

  openValueChanged() {
    if (this.openValue) {
      this.showContent()
      // Add event listeners
      document.addEventListener("click", this.clickOutsideHandler)
      document.addEventListener("keydown", this.keydownHandler)
    } else {
      this.hideContent()
      // Remove event listeners
      document.removeEventListener("click", this.clickOutsideHandler)
      document.removeEventListener("keydown", this.keydownHandler)
    }

    // Update trigger aria-expanded
    if (this.hasTriggerTarget) {
      this.triggerTarget.setAttribute("aria-expanded", this.openValue)
      this.triggerTarget.setAttribute("data-state", this.openValue ? "open" : "closed")
    }
  }

  showContent() {
    if (!this.hasContentTarget) return

    const content = this.contentTarget
    const trigger = this.triggerTarget

    // Show content
    content.classList.remove("hidden")
    content.setAttribute("data-state", "open")

    // Position the dropdown
    this.positionContent()

    // Focus first focusable element
    requestAnimationFrame(() => {
      const firstFocusable = content.querySelector(
        'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
      )
      if (firstFocusable) {
        firstFocusable.focus()
      }
    })
  }

  hideContent() {
    if (!this.hasContentTarget) return

    const content = this.contentTarget
    content.classList.add("hidden")
    content.setAttribute("data-state", "closed")

    // Return focus to trigger
    if (this.hasTriggerTarget) {
      this.triggerTarget.focus()
    }
  }

  positionContent() {
    if (!this.hasContentTarget || !this.hasTriggerTarget) return

    const content = this.contentTarget
    const trigger = this.triggerTarget
    const triggerRect = trigger.getBoundingClientRect()
    const sideOffset = this.sideOffsetValue

    // Set fixed positioning
    content.style.position = "fixed"
    content.style.zIndex = "9999"

    // Reset positioning
    content.style.top = ""
    content.style.left = ""
    content.style.right = ""
    content.style.bottom = ""

    // Calculate position based on side
    switch (this.sideValue) {
      case "top":
        content.style.bottom = `${window.innerHeight - triggerRect.top + sideOffset}px`
        content.style.left = `${triggerRect.left}px`
        break
      case "right":
        content.style.left = `${triggerRect.right + sideOffset}px`
        content.style.top = `${triggerRect.top}px`
        break
      case "bottom":
        content.style.top = `${triggerRect.bottom + sideOffset}px`
        content.style.left = `${triggerRect.left}px`
        break
      case "left":
        content.style.right = `${window.innerWidth - triggerRect.left + sideOffset}px`
        content.style.top = `${triggerRect.top}px`
        break
    }

    // Handle alignment for top/bottom positioning
    if (this.sideValue === "top" || this.sideValue === "bottom") {
      const contentRect = content.getBoundingClientRect()
      switch (this.alignValue) {
        case "start":
          // Already aligned to start
          break
        case "center":
          content.style.left = `${triggerRect.left + (triggerRect.width - contentRect.width) / 2}px`
          break
        case "end":
          content.style.left = ""
          content.style.right = `${window.innerWidth - triggerRect.right}px`
          break
      }
    }

    // Handle alignment for left/right positioning
    if (this.sideValue === "left" || this.sideValue === "right") {
      const contentRect = content.getBoundingClientRect()
      switch (this.alignValue) {
        case "start":
          // Already aligned to start
          break
        case "center":
          content.style.top = `${triggerRect.top + (triggerRect.height - contentRect.height) / 2}px`
          break
        case "end":
          content.style.top = ""
          content.style.bottom = `${window.innerHeight - triggerRect.bottom}px`
          break
      }
    }

    // Ensure content stays within viewport
    requestAnimationFrame(() => {
      const finalRect = content.getBoundingClientRect()

      if (finalRect.right > window.innerWidth) {
        content.style.left = ""
        content.style.right = "8px"
      }
      if (finalRect.left < 0) {
        content.style.left = "8px"
      }
      if (finalRect.bottom > window.innerHeight) {
        content.style.top = ""
        content.style.bottom = "8px"
      }
      if (finalRect.top < 0) {
        content.style.top = "8px"
      }
    })
  }

  clickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      event.preventDefault()
      this.close()
    }
  }

  // Called from menu items to close dropdown
  closeFromItem() {
    this.close()
  }
}
