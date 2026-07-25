import { Controller } from "@hotwired/stimulus"
import { isSpeechCancellation, speakText } from "controllers/speech_output"

export default class extends Controller {
  static targets = ["input", "speakButton"]
  static values = { text: String }
  
  async speak(event) {
    if (event) event.preventDefault()
    const text = (this.hasInputTarget ? this.inputTarget.value : this.textValue).trim()
    if (!text) return

    try {
      await speakText(text)
    } catch (error) {
      if (!isSpeechCancellation(error)) throw error
    }
  }

  async speakAndSubmit(event) {
    if (event) event.preventDefault()
    const form = this.element.closest("form")
    await this.speak(event)
    form?.requestSubmit()
  }
}
