import { Controller } from "@hotwired/stimulus"

// Light / dark / follow-the-system. The choice is a cookie so the server can
// render the right class on the very first paint; this controller only handles
// the switch itself.
const COOKIE = "recuerd0_theme"
const ONE_YEAR = 60 * 60 * 24 * 365

export default class extends Controller {
  static values = { theme: String }

  select(event) {
    event.preventDefault()

    const theme = this.themeValue
    document.cookie = `${COOKIE}=${encodeURIComponent(theme)};path=/;max-age=${ONE_YEAR};samesite=lax`

    const dark =
      theme === "dark" ||
      (theme === "system" && window.matchMedia("(prefers-color-scheme: dark)").matches)

    document.documentElement.classList.toggle("dark", dark)
    this.dispatch("changed", { detail: { theme }, prefix: "theme", target: document })
  }
}
