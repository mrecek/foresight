import { Controller } from "@hotwired/stimulus"

// Provides real-time inline validation feedback
// Usage: data-controller="inline-validator"
//        data-inline-validator-rules-value='{"required": true, "minLength": 3}'
export default class extends Controller {
  static targets = ["field", "error", "success"]
  static values = {
    rules: Object, // { required: true, minLength: 3, maxLength: 100, pattern: "regex" }
    debounce: { type: Number, default: 400 }
  }

  connect() {
    this.timeout = null
  }

  disconnect() {
    if (this.timeout) clearTimeout(this.timeout)
  }

  validate(event) {
    // Clear any pending validation
    if (this.timeout) clearTimeout(this.timeout)

    // Debounce the validation
    this.timeout = setTimeout(() => {
      this.performValidation()
    }, this.debounceValue)
  }

  validateNow() {
    this.performValidation()
  }

  performValidation() {
    const field = this.fieldTarget
    const value = field.value.trim()
    const rules = this.rulesValue
    const errors = []

    // Required validation
    if (rules.required && !value) {
      errors.push("This field is required")
    }

    // Min length validation
    if (rules.minLength && value.length < rules.minLength && value.length > 0) {
      errors.push(`Must be at least ${rules.minLength} characters`)
    }

    // Max length validation
    if (rules.maxLength && value.length > rules.maxLength) {
      errors.push(`Must be no more than ${rules.maxLength} characters`)
    }

    // Pattern validation
    if (rules.pattern && value) {
      const regex = new RegExp(rules.pattern)
      if (!regex.test(value)) {
        errors.push(rules.patternMessage || "Invalid format")
      }
    }

    // Numeric validation
    if (rules.numeric && value) {
      if (isNaN(parseFloat(value))) {
        errors.push("Must be a number")
      }
    }

    // Min value validation
    if (rules.min !== undefined && value) {
      const numValue = parseFloat(value)
      if (!isNaN(numValue) && numValue < rules.min) {
        errors.push(`Must be at least ${rules.min}`)
      }
    }

    // Max value validation
    if (rules.max !== undefined && value) {
      const numValue = parseFloat(value)
      if (!isNaN(numValue) && numValue > rules.max) {
        errors.push(`Must be no more than ${rules.max}`)
      }
    }

    this.displayValidation(errors, value)
  }

  displayValidation(errors, value) {
    const field = this.fieldTarget

    if (errors.length > 0) {
      // Show error state
      field.classList.add('border-danger-300', 'focus:ring-danger-500')
      field.classList.remove('border-success-300', 'focus:ring-success-500', 'border-neutral-300')

      if (this.hasErrorTarget) {
        this.errorTarget.textContent = errors[0]
        this.errorTarget.classList.remove('hidden')
      }

      if (this.hasSuccessTarget) {
        this.successTarget.classList.add('hidden')
      }
    } else if (value) {
      // Show success state
      field.classList.add('border-success-300', 'focus:ring-success-500')
      field.classList.remove('border-danger-300', 'focus:ring-danger-500', 'border-neutral-300')

      if (this.hasErrorTarget) {
        this.errorTarget.classList.add('hidden')
      }

      if (this.hasSuccessTarget) {
        this.successTarget.classList.remove('hidden')
      }
    } else {
      // Reset to neutral state
      field.classList.remove('border-danger-300', 'focus:ring-danger-500', 'border-success-300', 'focus:ring-success-500')
      field.classList.add('border-neutral-300')

      if (this.hasErrorTarget) {
        this.errorTarget.classList.add('hidden')
      }

      if (this.hasSuccessTarget) {
        this.successTarget.classList.add('hidden')
      }
    }
  }
}
