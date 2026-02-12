import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar"]

  connect() {
    this.links = this.element.querySelectorAll(".sidebar-link[data-section]")
    this.sections = document.querySelectorAll(".endpoint, .api-section")

    this.outsideClickHandler = this.outsideClickHandler.bind(this)
    this.escapeHandler = this.escapeHandler.bind(this)

    this.observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            const id = entry.target.id
            this.links.forEach((link) =>
              link.classList.toggle("active", link.dataset.section === id)
            )
          }
        })
      },
      { rootMargin: "-80px 0px -60% 0px", threshold: 0 }
    )

    this.sections.forEach((s) => {
      if (s.id) this.observer.observe(s)
    })
  }

  disconnect() {
    this.observer?.disconnect()
  }

  teardown() {
    this.observer?.disconnect()
    this.closeSidebar()
  }

  toggleSidebar() {
    this.sidebarTarget.classList.toggle("open")

    if (this.sidebarTarget.classList.contains("open")) {
      setTimeout(() => {
        document.addEventListener("mousedown", this.outsideClickHandler)
        document.addEventListener("keydown", this.escapeHandler)
      }, 0)
    } else {
      this.closeSidebar()
    }
  }

  outsideClickHandler(event) {
    if (this.sidebarTarget.contains(event.target) || event.target.closest(".mobile-toggle")) {
      return
    }

    this.closeSidebar()
  }

  escapeHandler(event) {
    if (event.key === "Escape") {
      this.closeSidebar()
    }
  }

  closeSidebar() {
    this.sidebarTarget.classList.remove("open")
    document.removeEventListener("mousedown", this.outsideClickHandler)
    document.removeEventListener("keydown", this.escapeHandler)
  }
}
