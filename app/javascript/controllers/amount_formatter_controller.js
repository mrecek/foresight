import { Controller } from "@hotwired/stimulus"

// Formats currency inputs and handles display formatting
// Usage: data-controller="amount-formatter"
export default class extends Controller {
  static targets = ["input", "display", "prefix"]

  connect() {
    // Format on initial load if there's a value
    if (this.hasInputTarget && this.inputTarget.value) {
      this.formatDisplay()
    }
  }

  format(event) {
    const input = event.target
    let value = input.value.replace(/[^0-9.]/g, '')

    // Handle multiple decimals
    const parts = value.split('.')
    if (parts.length > 2) {
      value = parts[0] + '.' + parts.slice(1).join('')
    }

    // Limit to 2 decimal places
    if (parts.length === 2 && parts[1].length > 2) {
      value = parts[0] + '.' + parts[1].slice(0, 2)
    }

    input.value = value
    this.formatDisplay()
  }

  formatDisplay() {
    if (!this.hasDisplayTarget) return

    const value = parseFloat(this.inputTarget.value) || 0
    this.displayTarget.textContent = this.formatCurrency(value)
  }

  formatOnBlur(event) {
    const input = event.target
    const value = parseFloat(input.value)

    if (!isNaN(value) && value >= 0) {
      // Format to 2 decimal places
      input.value = value.toFixed(2)
    } else if (input.value === '' || isNaN(value)) {
      input.value = ''
    }
  }

  formatCurrency(value) {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    }).format(value)
  }
}
