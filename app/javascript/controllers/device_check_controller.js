import { Controller } from "@hotwired/stimulus"
import { speakText } from "controllers/speech_output"

export default class extends Controller {
  static targets = ["status"]

  async testVoice(event) {
    event.preventDefault()

    await this.runCheck(event.currentTarget, async () => {
      await speakText(this.messages.testSentence)
      return this.messages.voiceSuccess
    }, this.messages.voiceError)
  }

  async testMicrophone(event) {
    event.preventDefault()

    await this.runCheck(event.currentTarget, async () => {
      if (!navigator.mediaDevices?.getUserMedia) throw new Error("unsupported")

      const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      stream.getTracks().forEach((track) => track.stop())
      return this.messages.microphoneSuccess
    }, this.messages.microphoneError)
  }

  get messages() {
    return this.hasStatusTarget ? this.statusTarget.dataset : {}
  }

  async runCheck(button, check, errorMessage) {
    if (!this.hasStatusTarget) return

    button.disabled = true
    button.setAttribute("aria-busy", "true")
    this.statusTarget.textContent = this.messages.testing

    try {
      this.statusTarget.textContent = await check()
    } catch (_error) {
      this.statusTarget.textContent = errorMessage
    } finally {
      button.disabled = false
      button.removeAttribute("aria-busy")
    }
  }
}
