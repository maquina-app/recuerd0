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
    this.onUndo = this.onUndo.bind(this)
    this.onLoad = this.onLoad.bind(this)

    // Capture phase: the dropdown closes on click and removes the item from
    // the DOM, so a bubbling listener can arrive after the target is detached.
    this.element.addEventListener("click", this.onUnpin, true)

    // The Undo link lives in the toaster, which is a sibling of this element
    // rather than a descendant, so the listener above never sees it. Without
    // this, unpinning restored focus correctly and undoing dropped it back to
    // <body> one keystroke later.
    document.addEventListener("click", this.onUndo, true)

    // The layout refreshes with `morph`, so the redirect back to this page
    // reuses this very element and Stimulus never calls connect() again.
    // turbo:load is the only signal that fires on both a morph render and a
    // full one.
    document.addEventListener("turbo:load", this.onLoad)

    this.#restore()
  }

  disconnect() {
    this.element.removeEventListener("click", this.onUnpin, true)
    document.removeEventListener("click", this.onUndo, true)
    document.removeEventListener("turbo:load", this.onLoad)
  }

  onLoad() {
    this.#restore()
  }

  onUnpin(event) {
    const item = event.target.closest("[data-pin-focus-target='unpin']")
    if (!item) return

    const index = this.#triggers().findIndex((trigger) => trigger.closest("li") === item.closest("li"))
    if (index >= 0) {
      this.lastIndex = index
      sessionStorage.setItem(KEY, String(index))
    }
  }

  // Undoing puts the card back roughly where it was, so aim at the same slot.
  onUndo(event) {
    if (!event.target.closest("[data-pin-focus-target='undo']")) return

    sessionStorage.setItem(KEY, String(this.lastIndex ?? 0))
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
    if (triggers.length === 0) {
      // Nothing left to focus — the last item in this view was removed. Fall
      // back to the heading so a keyboard user lands somewhere meaningful
      // instead of at the top of the document.
      const heading = this.element.querySelector("h1")
      if (heading) {
        heading.setAttribute("tabindex", "-1")
        heading.focus()
      }
      return
    }

    const target = triggers[Math.min(Number(stored), triggers.length - 1)]
    target?.focus()
  }
}
