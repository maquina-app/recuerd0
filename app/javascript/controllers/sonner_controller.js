import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="sonner"
export default class extends Controller {
  static values = {
    dismissAfter: { type: Number, default: 4000 },
    removeAfter: { type: Number, default: 150 },
    position: { type: String, default: "top-right" }
  }

  connect() {
    // Add enter animation
    this.element.classList.add("animate-in", "slide-in-from-top-2", "fade-in-0")

    // Set initial styles for animation
    this.element.style.animation = "toast-slide-in-right 150ms cubic-bezier(0.16, 1, 0.3, 1)"

    // Auto-dismiss after specified time
    if (this.dismissAfterValue > 0) {
      this.dismissTimeout = setTimeout(() => {
        this.dismiss()
      }, this.dismissAfterValue)
    }

    // Add swipe to dismiss on mobile
    this.addSwipeGesture()
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
    this.element.classList.remove("animate-in", "slide-in-from-top-2", "fade-in-0")
    this.element.classList.add("animate-out", "slide-out-to-right-2", "fade-out-0")
    this.element.style.animation = "toast-slide-out-right 150ms cubic-bezier(0.4, 0, 1, 1)"

    // Remove element after animation completes
    setTimeout(() => {
      this.element.remove()
    }, this.removeAfterValue)
  }

  addSwipeGesture() {
    let startX = 0
    let currentX = 0
    let startTime = 0

    const handleTouchStart = (e) => {
      startX = e.touches[0].clientX
      currentX = startX
      startTime = Date.now()
      this.element.style.transition = 'none'
    }

    const handleTouchMove = (e) => {
      currentX = e.touches[0].clientX
      const diffX = currentX - startX

      // Only allow swiping to the right
      if (diffX > 0) {
        this.element.style.transform = `translateX(${diffX}px)`
        this.element.style.opacity = 1 - (diffX / 200)
      }
    }

    const handleTouchEnd = () => {
      const diffX = currentX - startX
      const timeDiff = Date.now() - startTime
      const velocity = diffX / timeDiff

      this.element.style.transition = ''

      // If swiped far enough or fast enough, dismiss
      if (diffX > 100 || velocity > 0.5) {
        this.dismiss()
      } else {
        // Snap back
        this.element.style.transform = ''
        this.element.style.opacity = ''
      }
    }

    this.element.addEventListener('touchstart', handleTouchStart, { passive: true })
    this.element.addEventListener('touchmove', handleTouchMove, { passive: true })
    this.element.addEventListener('touchend', handleTouchEnd, { passive: true })
  }
}
