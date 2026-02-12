import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { active: { type: Number, default: 0 } }

  select(event) {
    this.activeValue = Number(event.currentTarget.dataset.index)
  }

  activeValueChanged() {
    this.tabTargets.forEach((tab, i) => {
      tab.dataset.state = i === this.activeValue ? "active" : "inactive"
      tab.setAttribute("aria-selected", i === this.activeValue)
    })

    this.panelTargets.forEach((panel, i) => {
      panel.classList.toggle("hidden", i !== this.activeValue)
    })
  }
}
