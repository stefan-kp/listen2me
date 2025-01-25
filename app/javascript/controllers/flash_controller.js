import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["message"]

  connect() {
    // Automatically hide flash after 5 seconds
    setTimeout(() => {
      this.close()
    }, 5000)
  }

  close() {
    this.messageTarget.remove()
  }
} 