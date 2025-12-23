import { Controller } from "@hotwired/stimulus"

// Shows/hides day_of_month and day_of_week fields based on frequency selection
export default class extends Controller {
  static targets = ["frequency", "dayOfMonth", "dayOfWeek"]

  connect() {
    this.toggle()
  }

  toggle() {
    const frequency = this.frequencyTarget.value

    // Show day_of_month for: monthly, semimonthly
    const showDayOfMonth = ["monthly", "semimonthly"].includes(frequency)

    // Show day_of_week for: weekly
    const showDayOfWeek = ["weekly"].includes(frequency)

    if (this.hasDayOfMonthTarget) {
      this.toggleField(this.dayOfMonthTarget, showDayOfMonth)
    }

    if (this.hasDayOfWeekTarget) {
      this.toggleField(this.dayOfWeekTarget, showDayOfWeek)
    }
  }

  toggleField(el, show) {
    if (show) {
      el.classList.remove('hidden', 'opacity-0')
      el.classList.add('opacity-100')
      el.querySelectorAll('input, select').forEach(input => {
        input.disabled = false
      })
    } else {
      el.classList.add('hidden', 'opacity-0')
      el.classList.remove('opacity-100')
      el.querySelectorAll('input, select').forEach(input => {
        input.disabled = true
      })
    }
  }
}
