import { Controller } from "@hotwired/stimulus"

// Dropdown menu controller with click-outside handling
// Usage: data-controller="dropdown"
export default class extends Controller {
  static targets = ["menu", "button"]
  static values = {
    open: { type: Boolean, default: false }
  }

  connect() {
    // Bind the click outside handler
    this.clickOutsideHandler = this.clickOutside.bind(this)
  }

  disconnect() {
    document.removeEventListener('click', this.clickOutsideHandler)
  }

  toggle(event) {
    event.stopPropagation()
    this.openValue = !this.openValue
  }

  open() {
    this.openValue = true
  }

  close() {
    this.openValue = false
  }

  clickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  openValueChanged() {
    if (this.openValue) {
      this.menuTarget.classList.remove('opacity-0', 'scale-95', 'pointer-events-none')
      this.menuTarget.classList.add('opacity-100', 'scale-100')
      document.addEventListener('click', this.clickOutsideHandler)

      // Update button state
      if (this.hasButtonTarget) {
        this.buttonTarget.setAttribute('aria-expanded', 'true')
      }
    } else {
      this.menuTarget.classList.add('opacity-0', 'scale-95', 'pointer-events-none')
      this.menuTarget.classList.remove('opacity-100', 'scale-100')
      document.removeEventListener('click', this.clickOutsideHandler)

      // Update button state
      if (this.hasButtonTarget) {
        this.buttonTarget.setAttribute('aria-expanded', 'false')
      }
    }
  }

  // Handle keyboard navigation
  keydown(event) {
    if (event.key === 'Escape') {
      this.close()
      this.buttonTarget?.focus()
    }
  }
}
