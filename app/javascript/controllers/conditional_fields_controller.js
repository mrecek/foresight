import { Controller } from "@hotwired/stimulus"

// Shows/hides fields based on another field's value
// Usage: data-controller="conditional-fields"
//        data-conditional-fields-show-when-value='{"transfer": ["destination_account"]}'
export default class extends Controller {
  static targets = ["trigger", "conditional"]
  static values = {
    showWhen: Object // { "triggerValue": ["fieldName1", "fieldName2"] }
  }

  connect() {
    this.toggle()
  }

  toggle() {
    const triggerValue = this.triggerTarget.value

    this.conditionalTargets.forEach(el => {
      const fieldName = el.dataset.field
      const shouldShow = this.shouldShowField(fieldName, triggerValue)

      if (shouldShow) {
        this.showField(el)
      } else {
        this.hideField(el)
      }
    })
  }

  shouldShowField(fieldName, triggerValue) {
    const rules = this.showWhenValue

    for (const [value, fields] of Object.entries(rules)) {
      if (triggerValue === value && fields.includes(fieldName)) {
        return true
      }
    }

    return false
  }

  showField(el) {
    el.classList.remove('hidden', 'opacity-0', 'scale-95')
    el.classList.add('opacity-100', 'scale-100')
    el.style.maxHeight = el.scrollHeight + 'px'

    // Enable inputs inside
    el.querySelectorAll('input, select, textarea').forEach(input => {
      input.disabled = false
    })

    // Animate to full height
    setTimeout(() => {
      el.style.maxHeight = 'none'
    }, 300)
  }

  hideField(el) {
    el.style.maxHeight = el.scrollHeight + 'px'

    // Force reflow
    el.offsetHeight

    el.classList.add('opacity-0', 'scale-95')
    el.style.maxHeight = '0px'

    // Disable and clear inputs inside
    el.querySelectorAll('input, select, textarea').forEach(input => {
      input.disabled = true
      // Don't clear the value - let Rails handle it
    })

    setTimeout(() => {
      el.classList.add('hidden')
    }, 300)
  }
}
