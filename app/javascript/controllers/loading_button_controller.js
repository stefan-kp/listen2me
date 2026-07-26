import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["icon", "label"]
  static values = {
    text: String
  }

  connect() {
    this.originalText = this.labelTarget.textContent
    this.boundSubmitStart = this.handleSubmitStart.bind(this)
    this.boundSubmitEnd = this.handleSubmitEnd.bind(this)
    document.addEventListener("turbo:submit-start", this.boundSubmitStart)
    document.addEventListener("turbo:submit-end", this.boundSubmitEnd)
  }

  disconnect() {
    document.removeEventListener("turbo:submit-start", this.boundSubmitStart)
    document.removeEventListener("turbo:submit-end", this.boundSubmitEnd)
  }

  handleSubmitStart(event) {
    if (event.target.contains(this.element)) {
      this.start()
    }
  }

  handleSubmitEnd(event) {
    if (event.target.contains(this.element)) {
      this.stop()
    }
  }

  start() {
    this.element.disabled = true
    this.labelTarget.textContent = this.textValue
    this.iconTarget.classList.add("animate-spin")
    this.iconTarget.style.animationDuration = "1s"
  }

  stop() {
    this.element.disabled = false
    this.labelTarget.textContent = this.originalText
    this.iconTarget.classList.remove("animate-spin")
    this.iconTarget.style.animationDuration = ""
  }
}
