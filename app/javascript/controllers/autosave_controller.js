// Derived from Writebook by 37signals — MIT licensed. See NOTICE.md.
// https://github.com/basecamp/writebook
import { Controller } from "@hotwired/stimulus"
import { submitForm } from "helpers/form_helpers"

const AUTOSAVE_INTERVAL = 3000

export default class extends Controller {
  static classes = [ "clean", "dirty", "saving" ]

  #timer

  // Lifecycle

  disconnect() {
    this.submit()
  }

  // Actions

  async submit() {
    if (this.#dirty) {
      await this.#save()
    }
  }

  change(event) {
    if (event.target.form === this.element && !this.#dirty) {
      this.#scheduleSave()
      this.#updateAppearance()
    }
  }

  // Private

  async #save() {
    this.#updateAppearance(true)
    this.#resetTimer()
    await submitForm(this.element)
    this.#updateAppearance()
  }

  #updateAppearance(saving = false) {
    this.element.classList.toggle(this.cleanClass, !this.#dirty)
    this.element.classList.toggle(this.dirtyClass, this.#dirty)
    this.element.classList.toggle(this.savingClass, saving)
  }

  #scheduleSave() {
    this.#timer = setTimeout(() => this.#save(), AUTOSAVE_INTERVAL)
  }

  #resetTimer() {
    clearTimeout(this.#timer)
    this.#timer = null
  }

  get #dirty() {
    return !!this.#timer
  }
}
