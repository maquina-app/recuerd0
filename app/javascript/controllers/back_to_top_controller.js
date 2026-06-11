import { Controller } from "@hotwired/stimulus"

// Floating "back to top" affordance for long doc pages. Hidden until the
// reader has scrolled past the threshold; respects prefers-reduced-motion.
export default class extends Controller {
  static values = { threshold: { type: Number, default: 600 } }

  connect() {
    this.onScroll = this.onScroll.bind(this)
    window.addEventListener("scroll", this.onScroll, { passive: true })
    this.onScroll()
  }

  disconnect() {
    window.removeEventListener("scroll", this.onScroll)
  }

  teardown() {
    this.disconnect()
  }

  onScroll() {
    this.element.classList.toggle("visible", window.scrollY > this.thresholdValue)
  }

  scrollTop() {
    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    window.scrollTo({ top: 0, behavior: reduce ? "auto" : "smooth" })
  }
}
