import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["shortcutHint"]
  static values = { searchUrl: String }

  connect() {
    const isMac = navigator.userAgentData
      ? /mac/i.test(navigator.userAgentData.platform)
      : /Mac|iPhone|iPad|iPod/.test(navigator.platform)
    this.shortcutHintTarget.textContent = isMac ? "⌘K" : "Ctrl+K"

    this._dialog = document.getElementById("search-command-dialog")
    this._input = document.getElementById("search-command-input")
    if (!this._dialog) return

    this.handleDialogClick = this.handleDialogClick.bind(this)
    this.handleFormSubmit = this.handleFormSubmit.bind(this)
    this.handleInputKeydown = this.handleInputKeydown.bind(this)

    this._dialog.addEventListener("click", this.handleDialogClick)
    this._dialog.querySelector("form").addEventListener("submit", this.handleFormSubmit)
    this._input.addEventListener("keydown", this.handleInputKeydown)
  }

  disconnect() {
    if (!this._dialog) return

    this._dialog.removeEventListener("click", this.handleDialogClick)
    this._dialog.querySelector("form")?.removeEventListener("submit", this.handleFormSubmit)
    this._input?.removeEventListener("keydown", this.handleInputKeydown)
    this._dialog = null
    this._input = null
  }

  open(event) {
    event.preventDefault()
    if (!this._dialog) return

    this._input.value = ""
    this._dialog.showModal()
    this._input.focus()
  }

  handleFormSubmit(event) {
    event.preventDefault()
    const query = this._input.value.trim()
    this._dialog.close()
    if (query.length > 0) {
      Turbo.visit(`${this.searchUrlValue}?q=${encodeURIComponent(query)}`)
    }
  }

  // Search inputs capture Esc to clear value, preventing native dialog close
  handleInputKeydown(event) {
    if (event.key === "Escape") {
      event.preventDefault()
      this._dialog.close()
    }
  }

  handleDialogClick(event) {
    if (event.target === this._dialog) {
      this._dialog.close()
    }
  }

  teardown() {
    if (this._dialog?.open) {
      this._dialog.close()
    }
    if (this._input) {
      this._input.value = ""
    }
  }
}
