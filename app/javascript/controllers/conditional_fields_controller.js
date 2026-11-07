import { Controller } from "@hotwired/stimulus"

// Keep conditional form layout and input availability in the same update.
export default class extends Controller {
  static targets = ["trigger", "conditional"]
  static values = { showWhen: Object }

  connect() {
    this.toggle()
  }

  toggle() {
    const fields = this.showWhenValue[this.triggerTarget.value] || []

    this.conditionalTargets.forEach(element => {
      const show = fields.includes(element.dataset.field)
      element.classList.toggle('hidden', !show)
      element.classList.remove('opacity-0', 'opacity-100', 'scale-95', 'scale-100')
      element.style.removeProperty('max-height')
      element.querySelectorAll('input, select, textarea').forEach(input => {
        input.disabled = !show
      })
    })
  }
}
