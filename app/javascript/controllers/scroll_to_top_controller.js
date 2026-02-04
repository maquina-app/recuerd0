import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button"]

  connect() {
    this.scrollContainer = this.element.closest("main") || window
    this.scrollHandler = this.toggleVisibility.bind(this)
    this.scrollContainer.addEventListener("scroll", this.scrollHandler, { passive: true })
    this.toggleVisibility()
  }

  disconnect() {
    this.scrollContainer.removeEventListener("scroll", this.scrollHandler)
  }

  teardown() {
    this.buttonTarget.classList.add("hidden")
  }

  scrollToTop() {
    this.scrollContainer.scrollTo({ top: 0, behavior: "smooth" })
  }

  toggleVisibility() {
    const scrollY = this.scrollContainer === window
      ? window.scrollY
      : this.scrollContainer.scrollTop

    if (scrollY > 300) {
      this.buttonTarget.classList.remove("hidden")
    } else {
      this.buttonTarget.classList.add("hidden")
    }
  }
}
