import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "hiddenInputs"]
  static values = { field: String }

  connect() {
    this.tags = this.getCurrentTags()
  }

  handleKeydown(event) {
    if (event.key === "Enter") {
      event.preventDefault()
      this.addTag()
    } else if (event.key === ",") {
      event.preventDefault()
      this.addTag()
    } else if (event.key === "Backspace" && this.inputTarget.value === "") {
      event.preventDefault()
      this.removeLastTag()
    }
  }

  addTag() {
    const input = this.inputTarget
    let tagName = input.value.trim()

    if (tagName.endsWith(",")) {
      tagName = tagName.slice(0, -1).trim()
    }

    if (tagName && !this.tags.includes(tagName)) {
      this.tags.push(tagName)
      this.renderTag(tagName)
      this.updateHiddenInputs()
      input.value = ""
    }
  }

  removeTag(event) {
    const tagName = event.currentTarget.dataset.tag
    const index = this.tags.indexOf(tagName)

    if (index > -1) {
      this.tags.splice(index, 1)
      event.currentTarget.closest("span").remove()
      this.updateHiddenInputs()
    }
  }

  removeLastTag() {
    if (this.tags.length > 0) {
      this.tags.pop()
      const container = this.inputTarget.parentElement
      const lastTag = container.querySelector("span:last-of-type:not([data-tag-input-target])")
      if (lastTag) {
        lastTag.remove()
      }
      this.updateHiddenInputs()
    }
  }

  getCurrentTags() {
    return Array.from(this.hiddenInputsTarget.querySelectorAll("input[type='hidden']"))
      .map(input => input.value)
  }

  renderTag(tagName) {
    const container = this.inputTarget.parentElement
    const escaped = this.escapeHtml(tagName)
    const tagElement = document.createElement("span")
    tagElement.className = "tag-badge"
    // icon_for is unavailable in JS, so the tag + x icons are inlined here using
    // the same paths as main_icon_svg_for(:tag) / main_icon_svg_for(:x).
    tagElement.innerHTML = `
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <path d="M12.586 2.586A2 2 0 0 0 11.172 2H4a2 2 0 0 0-2 2v7.172a2 2 0 0 0 .586 1.414l8.704 8.704a2.426 2.426 0 0 0 3.42 0l6.58-6.58a2.426 2.426 0 0 0 0-3.42z"></path>
        <circle cx="7.5" cy="7.5" r=".5" fill="currentColor"></circle>
      </svg>
      <span class="tag-label">${escaped}</span>
      <button type="button" class="tag-x" data-action="click->tag-input#removeTag" data-tag="${escaped}" aria-label="Remove ${escaped}">
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M18 6 6 18"></path>
          <path d="m6 6 12 12"></path>
        </svg>
      </button>
    `

    container.insertBefore(tagElement, this.inputTarget)
  }

  updateHiddenInputs() {
    this.hiddenInputsTarget.innerHTML = this.tags.map(tag =>
      `<input type="hidden" name="${this.fieldValue}[]" value="${this.escapeHtml(tag)}" />`
    ).join("")
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
