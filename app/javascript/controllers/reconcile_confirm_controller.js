import { Controller } from "@hotwired/stimulus"

// Handles reconcile confirmation with inline state change
// Usage: data-controller="reconcile-confirm"
export default class extends Controller {
    static targets = ["form", "confirmation", "date", "balance", "removeText", "todayOption", "todayCount", "todayPlural", "includeToday"]

    connect() {
        this.hideConfirmation()
        this.todayTransactionCount = 0
    }

    // Called when user clicks "Reconcile ✓" button
    showConfirmation(event) {
        event.preventDefault()

        // Get the current date from the form
        const dateInput = this.element.querySelector('input[name="balance_date"]')
        const balanceInput = this.element.querySelector('input[name="current_balance"]')

        if (dateInput && this.hasDateTarget) {
            // Use the already-formatted display text
            const dateDisplay = document.getElementById('reconcile_date_display')
            if (dateDisplay) {
                this.dateTarget.textContent = dateDisplay.textContent
            }
        }

        if (balanceInput && this.hasBalanceTarget) {
            const amount = parseFloat(balanceInput.value) || 0
            this.balanceTarget.textContent = '$' + amount.toLocaleString('en-US', {
                minimumFractionDigits: 2,
                maximumFractionDigits: 2
            })
        }

        // Count transactions: before today and on today
        const selectedDate = dateInput ? dateInput.value : null
        if (selectedDate && this.hasRemoveTextTarget) {
            const transactionRows = document.querySelectorAll('tr[data-transaction-date]')
            let pastCount = 0
            let todayCount = 0

            transactionRows.forEach(row => {
                const txnDate = row.dataset.transactionDate
                if (txnDate) {
                    if (txnDate < selectedDate) {
                        pastCount++
                    } else if (txnDate === selectedDate) {
                        todayCount++
                    }
                }
            })

            // Store for later use
            this.todayTransactionCount = todayCount

            // Update past transactions text
            if (pastCount > 0) {
                const plural = pastCount === 1 ? '' : 's'
                this.removeTextTarget.innerHTML = `<span class="text-warning-600">— removes <strong>${pastCount}</strong> old transaction${plural}</span>`
            } else {
                this.removeTextTarget.innerHTML = ''
            }

            // Show/hide today's transactions checkbox
            if (todayCount > 0 && this.hasTodayOptionTarget) {
                this.todayOptionTarget.classList.remove('hidden')
                this.todayCountTarget.textContent = todayCount
                this.todayPluralTarget.textContent = todayCount === 1 ? '' : 's'
                // Reset checkbox
                if (this.hasIncludeTodayTarget) {
                    this.includeTodayTarget.checked = false
                }
            } else if (this.hasTodayOptionTarget) {
                this.todayOptionTarget.classList.add('hidden')
            }
        }

        // Show confirmation, hide form
        this.formTarget.classList.add('hidden')
        this.confirmationTarget.classList.remove('hidden')
    }

    // Called when user clicks "Cancel"
    cancel(event) {
        event.preventDefault()
        this.hideConfirmation()
    }

    // Called when user clicks "Confirm"
    confirm(event) {
        // Add hidden field for include_today if checkbox is checked
        const form = this.element.querySelector('form')
        if (form) {
            if (this.hasIncludeTodayTarget && this.includeTodayTarget.checked) {
                const hiddenInput = document.createElement('input')
                hiddenInput.type = 'hidden'
                hiddenInput.name = 'include_today'
                hiddenInput.value = '1'
                form.appendChild(hiddenInput)
            }
            form.submit()
        }
    }

    hideConfirmation() {
        if (this.hasFormTarget) {
            this.formTarget.classList.remove('hidden')
        }
        if (this.hasConfirmationTarget) {
            this.confirmationTarget.classList.add('hidden')
        }
    }
}
