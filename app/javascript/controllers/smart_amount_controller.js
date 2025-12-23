import { Controller } from "@hotwired/stimulus"

// Handles smart amount input with automatic sign based on transaction type
// User always enters positive numbers, sign is determined by type selection
// Usage: data-controller="smart-amount"
export default class extends Controller {
  static targets = ["input", "hiddenInput", "typeButton", "display", "prefix", "wrapper"]
  static values = {
    type: { type: String, default: "expense" }
  }

  connect() {
    this.updateUI()
    this.syncHiddenInput()
  }

  selectType(event) {
    event.preventDefault()
    const button = event.currentTarget
    this.typeValue = button.dataset.type
    this.updateUI()
    this.syncHiddenInput()
  }

  updateAmount() {
    this.syncHiddenInput()
  }

  syncHiddenInput() {
    if (!this.hasHiddenInputTarget || !this.hasInputTarget) return

    const displayValue = parseFloat(this.inputTarget.value) || 0

    // Apply sign based on type
    let actualValue = displayValue
    if (this.typeValue === "expense" && displayValue > 0) {
      actualValue = -displayValue
    }

    this.hiddenInputTarget.value = actualValue
  }

  formatOnBlur() {
    const value = parseFloat(this.inputTarget.value)
    if (!isNaN(value)) {
      this.inputTarget.value = Math.abs(value).toFixed(2)
    }
    this.syncHiddenInput()
  }

  // When loading an existing transaction with negative amount
  loadExistingValue() {
    if (!this.hasHiddenInputTarget) return

    const storedValue = parseFloat(this.hiddenInputTarget.value) || 0

    if (storedValue < 0) {
      this.typeValue = "expense"
      this.inputTarget.value = Math.abs(storedValue).toFixed(2)
    } else if (storedValue > 0) {
      this.typeValue = "income"
      this.inputTarget.value = storedValue.toFixed(2)
    }

    this.updateUI()
  }

  updateUI() {
    // Update type buttons - clean pill toggle style
    this.typeButtonTargets.forEach(button => {
      const isSelected = button.dataset.type === this.typeValue

      // Remove all state classes
      button.classList.remove(
        'bg-success-500', 'text-white', 'shadow-sm',
        'bg-danger-500',
        'bg-transparent', 'text-neutral-500', 'hover:text-neutral-700'
      )

      if (isSelected) {
        if (button.dataset.type === 'income') {
          button.classList.add('bg-success-500', 'text-white', 'shadow-sm')
        } else {
          button.classList.add('bg-danger-500', 'text-white', 'shadow-sm')
        }
      } else {
        button.classList.add('bg-transparent', 'text-neutral-500', 'hover:text-neutral-700')
      }
    })

    // Update prefix color - just $ sign, type is shown by toggle
    if (this.hasPrefixTarget) {
      this.prefixTarget.classList.remove('text-success-600', 'text-danger-600')
      if (this.typeValue === 'income') {
        this.prefixTarget.classList.add('text-success-600')
      } else {
        this.prefixTarget.classList.add('text-danger-600')
      }
      this.prefixTarget.textContent = '$'
    }

    // Update wrapper focus ring color
    if (this.hasWrapperTarget) {
      this.wrapperTarget.classList.remove(
        'focus-within:ring-success-500', 'focus-within:border-success-300',
        'focus-within:ring-danger-500', 'focus-within:border-danger-300'
      )

      if (this.typeValue === 'income') {
        this.wrapperTarget.classList.add('focus-within:ring-success-500', 'focus-within:border-success-300')
      } else {
        this.wrapperTarget.classList.add('focus-within:ring-danger-500', 'focus-within:border-danger-300')
      }
    }
  }

  typeValueChanged() {
    this.updateUI()
    this.syncHiddenInput()
  }
}
