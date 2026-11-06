import { Controller } from "@hotwired/stimulus"

// Keeps a memory edit from being lost, without ever saving one on its own.
//
// Saving is always a choice between a new version and overwriting the current
// one, so there is no background write to make that choice for the person. Two
// guards overlap:
//
//   1. Cmd/Ctrl+S — the reflex this audience performs constantly. It presses the
//      form's primary button. House MD binds Ctrl+S to `strikethrough` and
//      stopPropagation()s it, so this listener runs in the CAPTURE phase to get
//      there first.
//   2. turbo:before-visit asks with the app's own dialog before leaving with unsaved
//      changes. beforeunload covers closing the tab or reloading, where only the
//      browser's prompt is allowed: pages can't replace that one.
//
// Bound to `house-md:change`, not `input`. Both fire on the current editor
// build, but `house-md:change` is documented as exactly one per commit while
// `input` is dispatched on top of the browser's own during IME composition.
export default class extends Controller {
  static targets = ["status", "editor", "shell", "title", "titleCount", "primarySubmit"]
  static values = {
    focusEditor: { type: Boolean, default: false },
    // A form re-rendered with an error holds text nothing has saved yet.
    startDirty: { type: Boolean, default: false },
    unsavedLabel: String,
    editorLostLabel: String,
    unloadPrompt: String
  }

  #dirty = false
  #editorLost = false

  connect() {
    this.onBeforeUnload = this.onBeforeUnload.bind(this)
    this.onBeforeVisit = this.onBeforeVisit.bind(this)
    this.onSaveShortcut = this.onSaveShortcut.bind(this)

    window.addEventListener("beforeunload", this.onBeforeUnload)
    document.addEventListener("turbo:before-visit", this.onBeforeVisit)
    // Capture phase: House MD calls stopPropagation() on the keys it handles,
    // and Ctrl+S is one of them.
    document.addEventListener("keydown", this.onSaveShortcut, true)

    this.#dirty = this.startDirtyValue
    this.#render()
    this.#renderPlaceholder()
    if (this.focusEditorValue) this.#focusEditor()
  }

  disconnect() {
    window.removeEventListener("beforeunload", this.onBeforeUnload)
    document.removeEventListener("turbo:before-visit", this.onBeforeVisit)
    document.removeEventListener("keydown", this.onSaveShortcut, true)
  }

  // Actions

  change() {
    this.#dirty = true
    this.#render()
    this.#renderPlaceholder()
  }

  // The last line of defence. An editor without its hidden input submits no content,
  // and a save that drops the body reads as a success. Nothing should get it into that
  // state now, but losing someone's text silently is the one failure worth refusing.
  submit(event) {
    if (this.hasEditorTarget && !this.editorTarget.querySelector('input[type="hidden"]')) {
      event.preventDefault()
      this.#editorLost = true
      this.#render()
      return
    }

    this.#dirty = false
  }

  // A failed save comes back as a morph, which keeps this controller connected and
  // syncs what it wrote into the DOM back to the server's empty markup, so connect()
  // never gets to mark the returned text as unsaved.
  morphed() {
    this.#dirty = this.#dirty || this.startDirtyValue
    this.#render()
    this.#renderPlaceholder()
  }

  // The title silently stops accepting keystrokes at maxlength. Show the
  // remaining count once it is close enough to matter.
  titleInput() {
    this.#dirty = true
    this.#render()

    if (!this.hasTitleTarget || !this.hasTitleCountTarget) return

    const max = Number(this.titleTarget.maxLength)
    const left = max - this.titleTarget.value.length
    const show = Number.isFinite(max) && max > 0 && left <= 25

    this.titleCountTarget.hidden = !show
    if (show) this.titleCountTarget.textContent = left
  }

  // Guards

  onSaveShortcut(event) {
    if (event.key !== "s" || !(event.metaKey || event.ctrlKey) || event.altKey) return
    if (!this.element.contains(document.activeElement)) return

    event.preventDefault()
    event.stopPropagation()
    this.element.requestSubmit(this.hasPrimarySubmitTarget ? this.primarySubmitTarget : null)
  }

  onBeforeUnload(event) {
    if (!this.#dirty) return
    event.preventDefault()
    // Browsers ignore custom text now, but a non-empty returnValue is still
    // what triggers the prompt in older engines.
    event.returnValue = this.unloadPromptValue
    return this.unloadPromptValue
  }

  onBeforeVisit(event) {
    if (!this.#dirty) return

    // The dialog can't answer in time to let this visit carry on, so stop it and start
    // it again if the person chooses to leave. The form carries the dialog's copy.
    event.preventDefault()
    const { url } = event.detail

    Turbo.config.forms.confirm(this.unloadPromptValue, null, this.element).then((leave) => {
      if (!leave) return

      this.#dirty = false
      Turbo.visit(url)
    })
  }

  // Private

  #renderPlaceholder() {
    if (!this.hasEditorTarget || !this.hasShellTarget) return
    // On connect the custom element may not be upgraded yet, in which case
    // `value` is undefined and the raw markdown is still its text content.
    const raw = this.editorTarget.value ?? this.editorTarget.textContent ?? ""
    const empty = raw.trim() === ""
    this.shellTarget.toggleAttribute("data-empty", empty)
  }

  // Silent until there is something to say: "Saved" on a form nothing has been
  // written from implied an autosave that does not exist.
  #render() {
    this.element.classList.toggle("is-dirty", this.#dirty)
    this.element.classList.toggle("is-clean", !this.#dirty)

    if (!this.hasStatusTarget) return

    if (this.#editorLost) this.statusTarget.textContent = this.editorLostLabelValue
    else this.statusTarget.textContent = this.#dirty ? this.unsavedLabelValue : ""
  }

  async #focusEditor() {
    if (!this.hasEditorTarget) return

    await customElements.whenDefined(this.editorTarget.localName)
    requestAnimationFrame(() => this.editorTarget.querySelector("[contenteditable]")?.focus())
  }
}
