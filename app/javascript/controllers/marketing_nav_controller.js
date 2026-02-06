import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["nav"]

  connect() {
    this.ticking = false
    this.scrollHandler = this.onScroll.bind(this)
    window.addEventListener("scroll", this.scrollHandler)
    this.onScroll()
  }

  disconnect() {
    window.removeEventListener("scroll", this.scrollHandler)
  }

  teardown() {
    this.disconnect()
    this.navTarget.classList.remove("scrolled")
  }

  onScroll() {
    if (!this.ticking) {
      requestAnimationFrame(() => {
        this.navTarget.classList.toggle("scrolled", window.scrollY > 60)
        this.ticking = false
      })
      this.ticking = true
    }
  }

  smoothScroll(event) {
    const href = event.currentTarget.getAttribute("href")
    if (!href?.startsWith("#")) return

    event.preventDefault()
    const target = document.querySelector(href)
    if (target) target.scrollIntoView({ behavior: "smooth", block: "start" })
  }
}
