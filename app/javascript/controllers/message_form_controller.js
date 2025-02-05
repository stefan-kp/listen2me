import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "input"]

  connect() {
    console.log("Message form controller connected")
  }

  // Verhindert doppeltes Absenden
  preventDoubleSubmit(event) {
    if (this.element.dataset.submitting === 'true') {
      event.preventDefault()
      return
    }
    this.element.dataset.submitting = 'true'
  }

  // Reset nach erfolgreicher Übermittlung
  reset() {
    this.element.dataset.submitting = 'false'
    this.inputTarget.value = ''
  }
} 