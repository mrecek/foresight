import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["source", "destination", "error"]

    connect() {
        this.validate()
    }

    validate() {
        if (!this.hasSourceTarget || !this.hasDestinationTarget) return

        const sourceId = this.sourceTarget.value
        const destinationId = this.destinationTarget.value

        if (sourceId && destinationId && sourceId === destinationId) {
            this.destinationTarget.classList.add("border-danger-500", "focus:ring-danger-500")
            if (this.hasErrorTarget) {
                this.errorTarget.textContent = "Source and destination accounts must be different"
                this.errorTarget.classList.remove("hidden")
            }
            return false
        } else {
            this.destinationTarget.classList.remove("border-danger-500", "focus:ring-danger-500")
            if (this.hasErrorTarget) {
                this.errorTarget.classList.add("hidden")
            }
            return true
        }
    }
}
