import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "copyIcon", "checkIcon"]

  selectAll() {
    this.sourceTarget.select()
  }

  copy() {
    const text = this.sourceTarget.value
    navigator.clipboard.writeText(text).then(() => {
      this.showFeedback()
    })
  }

  showFeedback() {
    this.copyIconTarget.classList.add("hidden")
    this.checkIconTarget.classList.remove("hidden")

    clearTimeout(this.feedbackTimeout)
    this.feedbackTimeout = setTimeout(() => {
      this.checkIconTarget.classList.add("hidden")
      this.copyIconTarget.classList.remove("hidden")
    }, 2000)
  }

  teardown() {
    clearTimeout(this.feedbackTimeout)
    this.copyIconTarget.classList.remove("hidden")
    this.checkIconTarget.classList.add("hidden")
  }
}
