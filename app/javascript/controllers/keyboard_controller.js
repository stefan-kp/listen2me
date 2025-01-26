import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.handleKeyboard = this.handleKeyboard.bind(this)
    document.addEventListener('keydown', this.handleKeyboard)
  }

  disconnect() {
    document.removeEventListener('keydown', this.handleKeyboard)
  }

  handleKeyboard(event) {
    // Alt + 1: Zum Hauptinhalt springen
    if (event.altKey && event.key === '1') {
      event.preventDefault()
      document.getElementById('main-content').focus()
    }

    // Alt + S: Zur Suche springen
    if (event.altKey && event.key === 's') {
      event.preventDefault()
      document.querySelector('.search-input')?.focus()
    }

    // Alt + N: Neuen Text eingeben
    if (event.altKey && event.key === 'n') {
      event.preventDefault()
      document.querySelector('.new-text-input')?.focus()
    }
  }
} 