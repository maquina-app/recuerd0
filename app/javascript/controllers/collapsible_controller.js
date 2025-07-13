import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "trigger", "chevron"]
  static values = {
    open: { type: Boolean, default: false }
  }

  connect() {
    // Set initial state without animation
    this.updateStateWithoutAnimation()
  }

  toggle() {
    this.openValue = !this.openValue
  }

  openValueChanged() {
    this.updateState()
  }

  updateStateWithoutAnimation() {
    const isOpen = this.openValue

    // Update data attributes
    this.element.setAttribute("data-state", isOpen ? "open" : "closed")
    if (this.hasTriggerTarget) {
      this.triggerTarget.setAttribute("aria-expanded", isOpen)
      this.triggerTarget.setAttribute("data-state", isOpen ? "open" : "closed")
    }

    // Handle chevron rotation
    if (this.hasChevronTarget) {
      if (isOpen) {
        this.chevronTarget.classList.add("rotate-90")
      } else {
        this.chevronTarget.classList.remove("rotate-90")
      }
    }

    // Set initial visibility
    if (this.hasContentTarget) {
      this.contentTarget.hidden = !isOpen
    }
  }

  updateState() {
    const isOpen = this.openValue

    // Update data attributes
    this.element.setAttribute("data-state", isOpen ? "open" : "closed")
    if (this.hasTriggerTarget) {
      this.triggerTarget.setAttribute("aria-expanded", isOpen)
      this.triggerTarget.setAttribute("data-state", isOpen ? "open" : "closed")
    }

    // Handle chevron rotation with transition
    if (this.hasChevronTarget) {
      if (isOpen) {
        this.chevronTarget.classList.add("rotate-90")
      } else {
        this.chevronTarget.classList.remove("rotate-90")
      }
    }

    // Animate the content
    if (this.hasContentTarget) {
      if (isOpen) {
        this.expand()
      } else {
        this.collapse()
      }
    }
  }

  expand() {
    const content = this.contentTarget

    // Show the content
    content.hidden = false

    // Use max-height for animation instead of height
    content.style.maxHeight = '0px'
    content.style.overflow = 'hidden'

    // Force a reflow
    content.offsetHeight

    // Add transition and set max-height
    content.style.transition = 'max-height 200ms ease-out'
    content.style.maxHeight = content.scrollHeight + 'px'

    // Clean up after animation
    setTimeout(() => {
      content.style.maxHeight = ''
      content.style.overflow = ''
      content.style.transition = ''
    }, 200)
  }

  collapse() {
    const content = this.contentTarget

    // Set current height
    content.style.maxHeight = content.scrollHeight + 'px'
    content.style.overflow = 'hidden'

    // Force a reflow
    content.offsetHeight

    // Add transition and collapse
    content.style.transition = 'max-height 200ms ease-out'
    content.style.maxHeight = '0px'

    // Hide and clean up after animation
    setTimeout(() => {
      content.hidden = true
      content.style.maxHeight = ''
      content.style.overflow = ''
      content.style.transition = ''
    }, 200)
  }
}
