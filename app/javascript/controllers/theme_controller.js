import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select"]

  connect() {
    this.sync()
  }

  change() {
    window.ForesightTheme?.setPreference(this.selectTarget.value)
  }

  sync() {
    const preference = window.ForesightTheme?.preference() || "dark"
    this.selectTarget.value = preference
  }
}
