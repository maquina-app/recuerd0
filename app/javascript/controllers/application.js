import { Application } from "@hotwired/stimulus"

const application = Application.start()

// Configure Stimulus development experience
application.debug = false
window.Stimulus   = application

// Global teardown pattern: before Turbo caches the page, call teardown()
// on any Stimulus controller that implements it.
// See: https://www.betterstimulus.com/turbo/teardown.html
document.addEventListener("turbo:before-cache", () => {
  application.controllers.forEach((controller) => {
    if (typeof controller.teardown === "function") {
      controller.teardown()
    }
  })
})

export { application }
