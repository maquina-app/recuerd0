import { Controller } from "@hotwired/stimulus"

// Hovering a relative time ("3 hours ago") shows the exact moment in the visitor's
// own time zone, which only the browser knows. The server renders no title, so the
// markup also wires turbo:morph@document to render: a morph syncs the attribute back
// to that empty markup without reconnecting the controller.
export default class extends Controller {
  connect() {
    this.render()
  }

  render() {
    const date = new Date(this.element.getAttribute("datetime"))
    if (Number.isNaN(date.getTime())) return

    this.element.title = date.toLocaleString(undefined, { dateStyle: "long", timeStyle: "short" })
  }
}
