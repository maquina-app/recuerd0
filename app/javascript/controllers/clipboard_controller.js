import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "copyIcon", "checkIcon"]
  static values = { text: { type: String, default: "" } }
  static classes = ["hidden"]

  get hiddenClass() {
    return super.hiddenClass || "hidden"
  }

  selectAll() {
    this.sourceTarget.select()
  }

  copy() {
    const text = this.textValue || this.sourceTarget.value
    navigator.clipboard.writeText(text).then(() => {
      this.showFeedback()
    }).catch(() => {})
  }

  showFeedback() {
    this.copyIconTarget.classList.add(this.hiddenClass)
    this.checkIconTarget.classList.remove(this.hiddenClass)

    clearTimeout(this.feedbackTimeout)
    this.feedbackTimeout = setTimeout(() => {
      this.checkIconTarget.classList.add(this.hiddenClass)
      this.copyIconTarget.classList.remove(this.hiddenClass)
    }, 2000)
  }

  teardown() {
    clearTimeout(this.feedbackTimeout)
    this.copyIconTarget.classList.remove(this.hiddenClass)
    this.checkIconTarget.classList.add(this.hiddenClass)
  }
}
