import { Controller } from "@hotwired/stimulus"

// Manages type selector buttons (income/expense/transfer) with visual feedback
// Usage: data-controller="type-selector"
export default class extends Controller {
  static targets = ["button", "input", "amountWrapper"]
  static values = {
    selected: String
  }

  connect() {
    // Initialize from hidden input or first button
    if (this.hasInputTarget && this.inputTarget.value) {
      this.selectedValue = this.inputTarget.value
    }
    this.updateButtons()
    this.updateAmountStyle()
  }

  select(event) {
    event.preventDefault()
    const button = event.currentTarget
    const value = button.dataset.value

    this.selectedValue = value

    // Update hidden input
    if (this.hasInputTarget) {
      this.inputTarget.value = value
    }

    this.updateButtons()
    this.updateAmountStyle()

    // Dispatch custom event for other controllers
    this.dispatch("changed", { detail: { value: value } })
  }

  updateButtons() {
    this.buttonTargets.forEach(button => {
      const isSelected = button.dataset.value === this.selectedValue
      const type = button.dataset.value

      // Reset all buttons - clean pill toggle style
      button.classList.remove(
        'bg-success-500', 'bg-danger-500', 'bg-primary-500',
        'text-white', 'shadow-sm',
        'bg-transparent', 'text-neutral-500', 'hover:text-neutral-700'
      )

      if (isSelected) {
        switch(type) {
          case 'income':
            button.classList.add('bg-success-500', 'text-white', 'shadow-sm')
            break
          case 'expense':
            button.classList.add('bg-danger-500', 'text-white', 'shadow-sm')
            break
          case 'transfer':
            button.classList.add('bg-primary-500', 'text-white', 'shadow-sm')
            break
        }
      } else {
        button.classList.add('bg-transparent', 'text-neutral-500', 'hover:text-neutral-700')
      }
    })
  }

  updateAmountStyle() {
    if (!this.hasAmountWrapperTarget) return

    const wrapper = this.amountWrapperTarget
    const prefix = wrapper.querySelector('[data-amount-prefix]')

    if (prefix) {
      prefix.classList.remove('text-success-600', 'text-danger-600', 'text-primary-600', 'text-neutral-400')
    }

    switch(this.selectedValue) {
      case 'income':
        if (prefix) prefix.classList.add('text-success-600')
        break
      case 'expense':
        if (prefix) prefix.classList.add('text-danger-600')
        break
      case 'transfer':
        if (prefix) prefix.classList.add('text-primary-600')
        break
      default:
        if (prefix) prefix.classList.add('text-neutral-400')
    }
  }
}
