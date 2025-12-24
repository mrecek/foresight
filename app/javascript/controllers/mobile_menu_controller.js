import { Controller } from "@hotwired/stimulus"

// Mobile navigation menu controller
// Usage: data-controller="mobile-menu" on the nav element
export default class extends Controller {
  static targets = ["menu", "button", "iconOpen", "iconClose"]
  static values = {
    open: { type: Boolean, default: false }
  }

  connect() {
    this.clickOutsideHandler = this.clickOutside.bind(this)
    this.keydownHandler = this.keydown.bind(this)
  }

  disconnect() {
    document.removeEventListener('click', this.clickOutsideHandler)
    document.removeEventListener('keydown', this.keydownHandler)
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

  keydown(event) {
    if (event.key === 'Escape') {
      this.close()
      this.buttonTarget.focus()
    }
  }

  openValueChanged() {
    if (this.openValue) {
      // Show menu
      this.menuTarget.classList.remove('hidden')

      // Toggle icons
      if (this.hasIconOpenTarget) {
        this.iconOpenTarget.classList.add('hidden')
      }
      if (this.hasIconCloseTarget) {
        this.iconCloseTarget.classList.remove('hidden')
      }

      // Update ARIA
      this.buttonTarget.setAttribute('aria-expanded', 'true')

      // Add event listeners
      document.addEventListener('click', this.clickOutsideHandler)
      document.addEventListener('keydown', this.keydownHandler)
    } else {
      // Hide menu
      this.menuTarget.classList.add('hidden')

      // Toggle icons
      if (this.hasIconOpenTarget) {
        this.iconOpenTarget.classList.remove('hidden')
      }
      if (this.hasIconCloseTarget) {
        this.iconCloseTarget.classList.add('hidden')
      }

      // Update ARIA
      this.buttonTarget.setAttribute('aria-expanded', 'false')

      // Remove event listeners
      document.removeEventListener('click', this.clickOutsideHandler)
      document.removeEventListener('keydown', this.keydownHandler)
    }
  }
}
