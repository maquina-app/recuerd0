import { Controller } from "@hotwired/stimulus"

// Scroll-reveal entrance, built as progressive enhancement. The `.reveal`
// elements are visible by default (see marketing.css); this controller only
// adds the on-scroll choreography and guarantees the page never stays blank if
// the observer can't run or never fires.
export default class extends Controller {
  connect() {
    this.revealables = Array.from(this.element.querySelectorAll(".reveal"))

    // No IntersectionObserver (legacy browsers): reveal everything immediately.
    if (!("IntersectionObserver" in window)) {
      this.revealAll()
      return
    }

    this.observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add("visible")
            this.observer.unobserve(entry.target)
          }
        })
      },
      { threshold: 0.1, rootMargin: "0px 0px -60px 0px" }
    )

    this.revealables.forEach((el) => this.observer.observe(el))

    // Safety net: if the observer never fires (headless capture, prerender, a
    // backgrounded tab that pauses callbacks), reveal everything so the content
    // can't ship blank. Real visitors hit the observer long before this.
    this.fallback = setTimeout(() => this.revealAll(), 1200)
  }

  revealAll() {
    this.revealables.forEach((el) => el.classList.add("visible"))
  }

  disconnect() {
    this.teardown()
  }

  teardown() {
    this.observer?.disconnect()
    if (this.fallback) clearTimeout(this.fallback)
  }
}
