import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Navigates to the search page without query params when the user
// clears the search input (via the native X button or manual deletion).
export default class extends Controller {
  clear(event) {
    if (event.target.value === "") {
      Turbo.visit(this.element.action)
    }
  }
}
