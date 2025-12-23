import { Controller } from "@hotwired/stimulus"

// Adds keyboard shortcuts and quick date selection to date inputs
// Usage: data-controller="date-helper"
export default class extends Controller {
  static targets = ["input", "shortcuts"]

  connect() {
    // Show shortcuts on focus
    if (this.hasShortcutsTarget) {
      this.shortcutsTarget.classList.add('opacity-0', 'max-h-0', 'overflow-hidden')
    }

    // Auto-set to today if empty (avoids server-side UTC timezone issues)
    if (this.hasInputTarget && !this.inputTarget.value) {
      this.inputTarget.value = this.formatDate(new Date())
    }
  }

  showShortcuts() {
    if (this.hasShortcutsTarget) {
      this.shortcutsTarget.classList.remove('opacity-0', 'max-h-0', 'overflow-hidden')
      this.shortcutsTarget.classList.add('opacity-100', 'max-h-20')
    }
  }

  hideShortcuts() {
    // Delay hiding to allow clicking shortcuts
    setTimeout(() => {
      if (this.hasShortcutsTarget && !this.element.contains(document.activeElement)) {
        this.shortcutsTarget.classList.add('opacity-0', 'max-h-0', 'overflow-hidden')
        this.shortcutsTarget.classList.remove('opacity-100', 'max-h-20')
      }
    }, 150)
  }

  handleKeypress(event) {
    const key = event.key.toLowerCase()

    // Don't interfere with normal typing in the date field
    if (event.target.type === 'date') return

    switch (key) {
      case 't':
        event.preventDefault()
        this.setToday()
        break
      case 'y':
        event.preventDefault()
        this.setYesterday()
        break
    }
  }

  setDate(event) {
    event.preventDefault()
    const dateType = event.currentTarget.dataset.date

    switch (dateType) {
      case 'today':
        this.setToday()
        break
      case 'yesterday':
        this.setYesterday()
        break
      case 'tomorrow':
        this.setTomorrow()
        break
      case 'first-of-month':
        this.setFirstOfMonth()
        break
      case 'last-of-month':
        this.setLastOfMonth()
        break
      case 'next-week':
        this.setNextWeek()
        break
    }

    // Trigger change event for any listeners
    this.inputTarget.dispatchEvent(new Event('change', { bubbles: true }))
  }

  setToday() {
    this.inputTarget.value = this.formatDate(new Date())
  }

  setYesterday() {
    const date = new Date()
    date.setDate(date.getDate() - 1)
    this.inputTarget.value = this.formatDate(date)
  }

  setTomorrow() {
    const date = new Date()
    date.setDate(date.getDate() + 1)
    this.inputTarget.value = this.formatDate(date)
  }

  setFirstOfMonth() {
    const date = new Date()
    date.setDate(1)
    this.inputTarget.value = this.formatDate(date)
  }

  setLastOfMonth() {
    const date = new Date()
    date.setMonth(date.getMonth() + 1, 0)
    this.inputTarget.value = this.formatDate(date)
  }

  setNextWeek() {
    const date = new Date()
    date.setDate(date.getDate() + 7)
    this.inputTarget.value = this.formatDate(date)
  }

  formatDate(date) {
    const year = date.getFullYear()
    const month = String(date.getMonth() + 1).padStart(2, '0')
    const day = String(date.getDate()).padStart(2, '0')
    return `${year}-${month}-${day}`
  }
}
