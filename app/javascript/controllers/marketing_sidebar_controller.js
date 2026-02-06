import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar"]

  connect() {
    this.links = this.element.querySelectorAll(".sidebar-link[data-section]")
    this.sections = document.querySelectorAll(".endpoint, .api-section")

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
  }

  closeSidebar() {
    this.sidebarTarget.classList.remove("open")
  }
}
