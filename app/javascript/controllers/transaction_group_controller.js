import { Controller } from "@hotwired/stimulus"

// Handles expand/collapse of transaction groups with smooth CSS animations
// Pure client-side toggle - no server requests
export default class extends Controller {
    static targets = ["icon"]
    static values = {
        groupId: String,
        expanded: { type: Boolean, default: false }
    }

    toggle(event) {
        // Prevent action buttons from triggering toggle
        if (event.target.closest('a, button')) {
            return
        }

        event.preventDefault()

        // Toggle expanded state
        this.expandedValue = !this.expandedValue
    }

    expandedValueChanged() {
        // Toggle expanded class on header element for styling
        if (this.expandedValue) {
            this.element.classList.add("expanded")
        } else {
            this.element.classList.remove("expanded")
        }

        // Rotate chevron icon
        if (this.hasIconTarget) {
            if (this.expandedValue) {
                this.iconTarget.classList.add("rotate-90")
            } else {
                this.iconTarget.classList.remove("rotate-90")
            }
        }

        // Find expanded rows by data attribute (siblings in table, not children)
        const expandedRows = document.querySelectorAll(`[data-group-id="${this.groupIdValue}"]`)

        expandedRows.forEach((row, index) => {
            if (this.expandedValue) {
                // Show with staggered animation
                row.classList.remove("hidden")
                row.style.animationDelay = `${index * 30}ms`
                row.classList.add("animate-fade-in")
            } else {
                // Hide immediately
                row.classList.add("hidden")
                row.classList.remove("animate-fade-in")
            }
        })
    }
}
