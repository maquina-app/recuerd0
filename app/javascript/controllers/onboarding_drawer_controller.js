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

  scopeCookie(event) {
    document.cookie =
      `recuerd0_onboarding_drawer_state=${event.detail.open}; path=/; SameSite=Lax`
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
