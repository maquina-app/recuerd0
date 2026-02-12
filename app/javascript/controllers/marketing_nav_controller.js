import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["nav", "overlay", "toggle"]

  connect() {
    this.ticking = false
    this.scrollHandler = this.onScroll.bind(this)
    this.escapeHandler = (e) => { if (e.key === "Escape") this.closeMenu() }
    window.addEventListener("scroll", this.scrollHandler)
    this.onScroll()
  }

  disconnect() {
    window.removeEventListener("scroll", this.scrollHandler)
  }

  teardown() {
    this.closeMenu()
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

  toggleMenu() {
    const isOpen = this.overlayTarget.classList.toggle("open")
    this.toggleTarget.classList.toggle("active", isOpen)

    if (isOpen) {
      document.body.style.overflow = "hidden"
      document.addEventListener("keydown", this.escapeHandler)
    } else {
      document.body.style.overflow = ""
      document.removeEventListener("keydown", this.escapeHandler)
    }
  }

  closeMenu() {
    if (this.hasOverlayTarget) this.overlayTarget.classList.remove("open")
    if (this.hasToggleTarget) this.toggleTarget.classList.remove("active")
    document.body.style.overflow = ""
    document.removeEventListener("keydown", this.escapeHandler)
  }

  overlayScroll(event) {
    this.closeMenu()
    this.smoothScroll(event)
  }

  smoothScroll(event) {
    const href = event.currentTarget.getAttribute("href")
    if (!href?.startsWith("#")) return

    event.preventDefault()
    const target = document.querySelector(href)
    if (target) target.scrollIntoView({ behavior: "smooth", block: "start" })
  }
}
