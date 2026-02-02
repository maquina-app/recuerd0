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
    const tagElement = document.createElement("span")
    tagElement.draggable = false
    tagElement.className = "transition-all border inline-flex items-center pl-2 bg-secondary text-secondary-foreground hover:bg-secondary/80 disabled:cursor-not-allowed disabled:opacity-50 text-sm h-8 rounded-sm border-solid cursor-default animate-fadeIn font-normal"
    tagElement.innerHTML = `
      ${this.escapeHtml(tagName)}
      <button class="inline-flex items-center justify-center whitespace-nowrap rounded-md text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring disabled:pointer-events-none disabled:opacity-50 hover:text-accent-foreground py-1 px-3 h-full hover:bg-transparent"
              type="button"
              data-action="click->tag-input#removeTag"
              data-tag="${this.escapeHtml(tagName)}">
        <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-x">
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
