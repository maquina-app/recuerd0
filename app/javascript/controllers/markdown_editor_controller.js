import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["writeTab", "previewTab", "writePane", "previewPane", "textarea", "previewForm", "contentInput"]
  static values = { mode: { type: String, default: "write" } }

  showWrite() {
    this.modeValue = "write"
    this.syncTabs()
  }

  showPreview() {
    this.modeValue = "preview"
    this.syncTabs()
    this.contentInputTarget.value = this.textareaTarget.value
    this.previewFormTarget.requestSubmit()
  }

  syncTabs() {
    const isWrite = this.modeValue === "write"

    this.writeTabTarget.setAttribute("aria-selected", isWrite)
    this.previewTabTarget.setAttribute("aria-selected", !isWrite)

    this.writeTabTarget.dataset.state = isWrite ? "active" : "inactive"
    this.previewTabTarget.dataset.state = isWrite ? "inactive" : "active"

    this.writePaneTarget.classList.toggle("hidden", !isWrite)
    this.previewPaneTarget.classList.toggle("hidden", isWrite)
  }

  teardown() {
    this.modeValue = "write"
    this.syncTabs()
  }
}
