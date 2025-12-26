import { Controller } from "@hotwired/stimulus"

// Shows/hides day_of_month and day_of_week fields based on frequency selection
// Intelligently syncs day_of_month with anchor_date until user manually edits it
export default class extends Controller {
  static targets = ["frequency", "dayOfMonth", "dayOfWeek", "anchorDate"]

  connect() {
    this.userEditedDayOfMonth = false
    this.setupListeners()
    this.toggle()
  }

  setupListeners() {
    // Listen for anchor date changes to auto-sync day of month
    if (this.hasAnchorDateTarget) {
      const anchorInput = this.anchorDateTarget.querySelector('input')
      if (anchorInput) {
        anchorInput.addEventListener('change', () => {
          const frequency = this.frequencyTarget.value
          const shouldSync = ["monthly", "semimonthly"].includes(frequency)
          if (shouldSync) {
            this.syncDayOfMonth()
          }
        })
      }
    }

    // Track manual edits to day of month to stop auto-syncing
    if (this.hasDayOfMonthTarget) {
      const dayInput = this.dayOfMonthTarget.querySelector('input')
      if (dayInput) {
        dayInput.addEventListener('input', () => {
          this.userEditedDayOfMonth = true
        })
      }
    }
  }

  toggle() {
    const frequency = this.frequencyTarget.value

    // Show day_of_month only for semimonthly (to specify first day paired with 15th)
    // For monthly, day is extracted from anchor_date automatically by the backend
    const showDayOfMonth = ["semimonthly"].includes(frequency)

    // Show day_of_week for: weekly
    const showDayOfWeek = ["weekly"].includes(frequency)

    if (this.hasDayOfMonthTarget) {
      this.toggleField(this.dayOfMonthTarget, showDayOfMonth)

      // Reset manual edit flag and sync when frequency changes to semimonthly
      if (showDayOfMonth) {
        this.userEditedDayOfMonth = false
        this.syncDayOfMonth()
      }
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

  syncDayOfMonth() {
    const dayOfMonthInput = this.dayOfMonthTarget.querySelector('input')

    // Only sync if user hasn't manually edited OR field is empty
    if (dayOfMonthInput &&
      (!this.userEditedDayOfMonth || !dayOfMonthInput.value) &&
      this.hasAnchorDateTarget) {
      const anchorDateInput = this.anchorDateTarget.querySelector('input')

      if (anchorDateInput && anchorDateInput.value) {
        // Parse date in local timezone (avoid UTC conversion issues)
        // Input format is YYYY-MM-DD, which new Date() interprets as UTC midnight
        const [year, month, day] = anchorDateInput.value.split('-').map(Number)
        const date = new Date(year, month - 1, day) // month is 0-indexed

        // Ensure valid date
        if (!isNaN(date.getTime())) {
          const dayOfMonth = date.getDate()
          dayOfMonthInput.value = dayOfMonth
        }
      }
    }
  }
}
