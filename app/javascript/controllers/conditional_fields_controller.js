import { Controller } from "@hotwired/stimulus"

// Shows/hides fields based on another field's value
// Usage: data-controller="conditional-fields"
//        data-conditional-fields-show-when-value='{"transfer": ["destination_account"]}'
export default class extends Controller {
  static targets = ["trigger", "conditional"]
  static values = {
    showWhen: Object // { "triggerValue": ["fieldName1", "fieldName2"] }
  }

  initialize() {
    this.transitionTimers = new WeakMap()
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
    this.clearTransitionTimer(el)
    el.classList.remove('hidden', 'opacity-0', 'scale-95')
    el.classList.add('opacity-100', 'scale-100')
    el.style.maxHeight = el.scrollHeight + 'px'

    // Enable inputs inside
    el.querySelectorAll('input, select, textarea').forEach(input => {
      input.disabled = false
    })

    // Animate to full height
    this.transitionTimers.set(el, setTimeout(() => {
      el.style.maxHeight = 'none'
      this.transitionTimers.delete(el)
    }, 300))
  }

  hideField(el) {
    this.clearTransitionTimer(el)
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

    this.transitionTimers.set(el, setTimeout(() => {
      el.classList.add('hidden')
      this.transitionTimers.delete(el)
    }, 300))
  }

  clearTransitionTimer(el) {
    const timer = this.transitionTimers.get(el)
    if (timer) clearTimeout(timer)
    this.transitionTimers.delete(el)
  }
}
