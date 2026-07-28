import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static outlets = ["toggle-group"]
  static targets = ["terminalPanel", "chatPanel"]

  connect() {
    this.selectedValue = "terminal"
    this.showPanel(this.selectedValue)
  }

  toggleGroupOutletConnected(outlet) {
    this.selectedValue = outlet.getValue() || this.selectedValue
    this.showPanel(this.selectedValue)
  }

  selectionChanged(event) {
    const value = event.detail.value

    if (value) {
      this.selectedValue = value
      this.showPanel(value)
      return
    }

    queueMicrotask(() => {
      if (!this.hasToggleGroupOutlet) return
      if (this.toggleGroupOutlet.getValue() !== null) return

      this.toggleGroupOutlet.select(this.selectedValue)
    })
  }

  toggleItem(event) {
    const toggle = event.currentTarget
    const item = toggle.closest("[data-onboarding-item]")
    const body = item?.querySelector("[data-onboarding-item-body]")
    const title = item?.querySelector("[data-onboarding-item-title]")

    if (!item || !body || !title) return

    const expanding = body.hidden
    const folded = !expanding

    body.hidden = folded
    item.dataset.folded = folded
    toggle.setAttribute("aria-expanded", expanding)
    toggle.textContent = expanding ? "Hide" : "Show"
    title.classList.toggle("font-medium", folded)
    title.classList.toggle("text-muted-foreground", folded)
    title.classList.toggle("font-semibold", !folded)
  }

  showPanel(value) {
    if (this.hasTerminalPanelTarget) {
      this.terminalPanelTarget.hidden = value !== "terminal"
    }

    if (this.hasChatPanelTarget) {
      this.chatPanelTarget.hidden = value !== "chat"
    }
  }
}
