import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "copyIcon", "checkIcon", "status"]
  static values = { text: { type: String, default: "" } }
  static classes = ["hidden"]

  get hiddenClass() {
    return super.hiddenClass || "hidden"
  }

  selectAll() {
    this.sourceTarget.select()
  }

  copy() {
    // Read from the text value, an input's value, or a non-input element's
    // text (e.g. a <code> block), in that order.
    const text = this.textValue || this.sourceTarget.value || this.sourceTarget.textContent

    // navigator.clipboard is undefined on any non-secure origin, which includes
    // a self-hosted install reached over plain http on a LAN. Swallowing that
    // rejection left the button looking functional and doing nothing forever.
    if (!navigator.clipboard?.writeText) {
      this.showFailure(text)
      return
    }

    navigator.clipboard.writeText(text)
      .then(() => this.showFeedback())
      .catch(() => this.showFailure(text))
  }

  showFeedback() {
    this.copyIconTarget.classList.add(this.hiddenClass)
    this.checkIconTarget.classList.remove(this.hiddenClass)
    this.announce(this.element.dataset.clipboardCopiedText || "Copied")

    clearTimeout(this.feedbackTimeout)
    this.feedbackTimeout = setTimeout(() => {
      this.checkIconTarget.classList.add(this.hiddenClass)
      this.copyIconTarget.classList.remove(this.hiddenClass)
    }, 2000)
  }

  // When we cannot write to the clipboard, select the value so the visitor can
  // copy it by hand, and say so out loud rather than failing silently.
  showFailure(text) {
    const message = this.element.dataset.clipboardFailedText || `Copy manually: ${text}`
    this.announce(message)

    // No modal fallback: the value is rendered on the page precisely so it can
    // always be selected by hand.
    if (this.hasSourceTarget) {
      this.sourceTarget.focus()
      this.sourceTarget.select?.()
    }
  }

  announce(message) {
    if (!this.hasStatusTarget) return
    this.statusTarget.textContent = message
  }

  teardown() {
    clearTimeout(this.feedbackTimeout)
    this.copyIconTarget.classList.remove(this.hiddenClass)
    this.checkIconTarget.classList.add(this.hiddenClass)
  }
}
