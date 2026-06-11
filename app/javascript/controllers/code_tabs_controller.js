import { Controller } from "@hotwired/stimulus"

// Tabbed code samples following the WAI-ARIA tabs pattern: click or arrow-key
// selection, with roving tabindex so only the active tab is in the tab order.
export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { active: { type: Number, default: 0 } }

  select(event) {
    this.activeValue = Number(event.currentTarget.dataset.index)
  }

  navigate(event) {
    const count = this.tabTargets.length
    let next = null
    switch (event.key) {
      case "ArrowRight":
      case "ArrowDown":
        next = (this.activeValue + 1) % count
        break
      case "ArrowLeft":
      case "ArrowUp":
        next = (this.activeValue - 1 + count) % count
        break
      case "Home":
        next = 0
        break
      case "End":
        next = count - 1
        break
      default:
        return
    }
    event.preventDefault()
    this.activeValue = next
    this.tabTargets[next].focus()
  }

  activeValueChanged() {
    this.tabTargets.forEach((tab, i) => {
      const active = i === this.activeValue
      tab.dataset.state = active ? "active" : "inactive"
      tab.setAttribute("aria-selected", active)
      tab.setAttribute("tabindex", active ? "0" : "-1")
    })

    this.panelTargets.forEach((panel, i) => {
      panel.classList.toggle("hidden", i !== this.activeValue)
    })
  }
}
