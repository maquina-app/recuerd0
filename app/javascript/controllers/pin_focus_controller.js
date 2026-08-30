import { Controller } from "@hotwired/stimulus"

// Keeps a place in the list when a card is removed.
//
// Unpinning redirects back to the same page, so the card the user activated is
// gone and focus lands on <body> — a keyboard or screen-reader user restarts
// from the top of the document with no idea which item left. There is nothing
// to restore focus *to*, so we restore focus to the same position: the actions
// trigger that now occupies the removed card's slot, or the last one if the
// removed card was at the end.
//
// The index survives in sessionStorage because the redirect is a real
// navigation; an instance variable would not outlive it.
const KEY = "recuerd0:pin-focus-index"

export default class extends Controller {

  connect() {
    this.onUnpin = this.onUnpin.bind(this)
    this.onLoad = this.onLoad.bind(this)

    // Capture phase: the dropdown closes on click and removes the item from
    // the DOM, so a bubbling listener can arrive after the target is detached.
    this.element.addEventListener("click", this.onUnpin, true)

    // The layout refreshes with `morph`, so the redirect back to this page
    // reuses this very element and Stimulus never calls connect() again.
    // turbo:load is the only signal that fires on both a morph render and a
    // full one.
    document.addEventListener("turbo:load", this.onLoad)

    this.#restore()
  }

  disconnect() {
    this.element.removeEventListener("click", this.onUnpin, true)
    document.removeEventListener("turbo:load", this.onLoad)
  }

  onLoad() {
    this.#restore()
  }

  onUnpin(event) {
    const item = event.target.closest("[data-pin-focus-target='unpin']")
    if (!item) return

    const index = this.#triggers().findIndex((trigger) => trigger.closest("li") === item.closest("li"))
    if (index >= 0) sessionStorage.setItem(KEY, String(index))
  }

  // Private

  #triggers() {
    return Array.from(this.element.querySelectorAll("[data-dropdown-menu-target='trigger']"))
  }

  #restore() {
    const stored = sessionStorage.getItem(KEY)
    if (stored === null) return
    sessionStorage.removeItem(KEY)

    const triggers = this.#triggers()
    if (triggers.length === 0) return

    const target = triggers[Math.min(Number(stored), triggers.length - 1)]
    target?.focus()
  }
}
