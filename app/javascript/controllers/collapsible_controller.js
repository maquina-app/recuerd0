import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "trigger", "chevron"]
  static values = {
    open: { type: Boolean, default: false },
    id: { type: String, default: "" },
    cookieName: { type: String, default: "recuerd0_collapsible_states" },
    cookieMaxAge: { type: Number, default: 60 * 60 * 24 * 365 }
  }

  connect() {
    // No need to load from cookie - it's already set from the server
    // Just set the initial state without animation
    this.setInitialState()
  }

  toggle() {
    this.openValue = !this.openValue
    this.updateState(true) // animate = true

    // Save state to cookie if ID is provided
    if (this.idValue) {
      this.saveState()
    }
  }

  openValueChanged() {
    // Don't do anything here - we'll handle updates manually
  }

  setInitialState() {
    const isOpen = this.openValue

    // Update data attributes
    this.element.setAttribute("data-state", isOpen ? "open" : "closed")
    if (this.hasTriggerTarget) {
      this.triggerTarget.setAttribute("aria-expanded", isOpen)
      this.triggerTarget.setAttribute("data-state", isOpen ? "open" : "closed")
    }

    // Set initial visibility without animation
    if (this.hasContentTarget) {
      if (!isOpen) {
        this.contentTarget.hidden = true
      }
    }
  }

  updateState(animate = false) {
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

    // Handle content visibility
    if (this.hasContentTarget) {
      if (animate) {
        if (isOpen) {
          this.expand()
        } else {
          this.collapse()
        }
      } else {
        // No animation
        if (isOpen) {
          this.contentTarget.hidden = false
        } else {
          this.contentTarget.hidden = true
        }
      }
    }
  }

  expand() {
    const content = this.contentTarget

    // Show the content
    content.hidden = false

    // Use max-height for animation
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

  // Cookie management methods
  saveState() {
    const states = this.getAllSavedStates()
    states[this.idValue] = this.openValue
    this.setCookie(this.cookieNameValue, JSON.stringify(states), this.cookieMaxAgeValue)
  }

  getAllSavedStates() {
    const cookieValue = this.getCookie(this.cookieNameValue)
    if (cookieValue) {
      try {
        return JSON.parse(cookieValue)
      } catch (e) {
        return {}
      }
    }
    return {}
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
