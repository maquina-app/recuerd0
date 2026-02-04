import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Navigates to a URL selected from a <select> element.
//
// Usage:
//   <select data-controller="navigate" data-action="change->navigate#visit">
//     <option value="/path/to/page">Page</option>
//   </select>
export default class extends Controller {
  visit() {
    Turbo.visit(this.element.value)
  }
}
