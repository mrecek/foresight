import { Controller } from "@hotwired/stimulus"

// Auto-submit form on element change
// Usage: data-controller="auto-submit" data-action="change->auto-submit#submit"
export default class extends Controller {
  submit() {
    this.element.form.submit()
  }
}
