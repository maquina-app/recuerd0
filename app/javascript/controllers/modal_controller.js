import { Controller } from "@hotwired/stimulus"

// Opens a <dialog> that holds its own form. The turbo-confirm dialog only asks yes or
// no, so anything that needs an answer filled in goes here.
export default class extends Controller {
  static targets = ["dialog"]

  open() {
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }
}
