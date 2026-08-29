import { Controller } from "@hotwired/stimulus"
import { submitForm } from "helpers/form_helpers"

// Keeps a memory edit from being lost.
//
// Before this, the editor had no autosave, no dirty state and no navigation
// guard: typing and then clicking any link discarded the work silently. Three
// separate guards now overlap, because each one has a hole the others cover:
//
//   1. Autosave, 3s after the last change — handles the common case.
//   2. Cmd/Ctrl+S — the reflex this audience performs constantly. House MD
//      binds Ctrl+S to `strikethrough` and stopPropagation()s it, so this
//      listener runs in the CAPTURE phase to get there first.
//   3. beforeunload + turbo:before-visit — covers the <3s window and any
//      autosave that failed.
//
// Bound to `house-md:change`, not `input`. Both fire on the current editor
// build, but `house-md:change` is documented as exactly one per commit while
// `input` is dispatched on top of the browser's own during IME composition.
const AUTOSAVE_DELAY = 3000

export default class extends Controller {
  static targets = ["status", "editor", "shell", "title", "titleCount"]
  static values = {
    // Off for an unpersisted memory: a background POST every 3 seconds would
    // create a new record per keystroke burst. There, Cmd+S submits for real
    // and the unload guard is the only protection.
    autosave: { type: Boolean, default: false },
    savedLabel: String,
    savingLabel: String,
    unsavedLabel: String,
    failedLabel: String,
    unloadPrompt: String
  }

  #timer = null
  #dirty = false
  #saving = false
  #failed = false

  connect() {
    this.onBeforeUnload = this.onBeforeUnload.bind(this)
    this.onBeforeVisit = this.onBeforeVisit.bind(this)
    this.onSaveShortcut = this.onSaveShortcut.bind(this)

    window.addEventListener("beforeunload", this.onBeforeUnload)
    document.addEventListener("turbo:before-visit", this.onBeforeVisit)
    // Capture phase: House MD calls stopPropagation() on the keys it handles,
    // and Ctrl+S is one of them.
    document.addEventListener("keydown", this.onSaveShortcut, true)

    this.#render()
    this.#renderPlaceholder()
  }

  disconnect() {
    this.teardown()
    window.removeEventListener("beforeunload", this.onBeforeUnload)
    document.removeEventListener("turbo:before-visit", this.onBeforeVisit)
    document.removeEventListener("keydown", this.onSaveShortcut, true)
  }

  // Called on turbo:before-cache via the application.js teardown convention.
  teardown() {
    clearTimeout(this.#timer)
    this.#timer = null
  }

  // Actions

  change() {
    this.#dirty = true
    clearTimeout(this.#timer)
    if (this.autosaveValue) this.#timer = setTimeout(() => this.save(), AUTOSAVE_DELAY)
    this.#render()
    this.#renderPlaceholder()
  }

  // The form's own submit — let it through, but stop a queued autosave from
  // racing it.
  submit() {
    this.#dirty = false
    this.teardown()
  }

  async save() {
    if (!this.#dirty || this.#saving) return

    // Nothing to autosave into yet — let the form create the record normally.
    if (!this.autosaveValue) {
      this.teardown()
      this.element.requestSubmit()
      return
    }

    this.teardown()
    this.#saving = true
    this.#render()

    try {
      const response = await submitForm(this.element, { autosave: "1" })
      this.#dirty = !response.ok
      this.#failed = !response.ok
    } catch {
      this.#failed = true
    } finally {
      this.#saving = false
      this.#render()
    }
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
    this.save()
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
    if (!window.confirm(this.unloadPromptValue)) event.preventDefault()
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

  #render() {
    const form = this.element
    form.classList.toggle("is-dirty", this.#dirty && !this.#saving)
    form.classList.toggle("is-saving", this.#saving)
    form.classList.toggle("is-clean", !this.#dirty && !this.#saving)

    if (!this.hasStatusTarget) return

    if (this.#saving) {
      this.statusTarget.textContent = this.savingLabelValue
    } else if (this.#failed) {
      this.statusTarget.textContent = this.failedLabelValue
    } else if (this.#dirty) {
      this.statusTarget.textContent = this.unsavedLabelValue
    } else {
      this.statusTarget.textContent = this.savedLabelValue
    }
  }
}
