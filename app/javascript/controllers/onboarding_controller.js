import { Controller } from "@hotwired/stimulus"
import { speakText } from "controllers/speech_output"

const SPEECH_MODE_STORAGE_KEY = "listen2me:speech-mode"

export default class extends Controller {
  static targets = [
    "panel",
    "progress",
    "progressBar",
    "progressLabel",
    "back",
    "next",
    "submit",
    "audioStatus"
  ]

  connect() {
    this.currentStep = 0
    this.showStep({ focus: false })
  }

  next(event) {
    event.preventDefault()
    if (this.currentStep >= this.panelTargets.length - 1) return

    this.currentStep += 1
    this.showStep()
  }

  back(event) {
    event.preventDefault()
    if (this.currentStep === 0) return

    this.currentStep -= 1
    this.showStep()
  }

  showStep({ focus = true } = {}) {
    const stepNumber = this.currentStep + 1
    const total = this.panelTargets.length

    this.panelTargets.forEach((panel, index) => {
      panel.hidden = index !== this.currentStep
    })
    this.backTarget.hidden = this.currentStep === 0
    this.nextTarget.hidden = this.currentStep === total - 1
    this.submitTarget.hidden = this.currentStep !== total - 1
    this.progressTarget.setAttribute("aria-valuenow", String(stepNumber))
    this.progressBarTarget.style.width = `${(stepNumber / total) * 100}%`
    this.progressLabelTarget.textContent = this.progressLabelTarget.dataset.stepTemplate
      .replace("__CURRENT__", String(stepNumber))
      .replace("__TOTAL__", String(total))

    if (focus) {
      this.panelTargets[this.currentStep].querySelector("legend")?.focus({ preventScroll: true })
    }
  }

  persistPreferences() {
    const selectedMode = this.element.querySelector(
      "input[name='user[preferred_speech_mode]']:checked"
    )?.value

    if (selectedMode) window.localStorage.setItem(SPEECH_MODE_STORAGE_KEY, selectedMode)
  }

  async testVoice(event) {
    event.preventDefault()
    const messages = this.audioStatusTarget.dataset

    try {
      await speakText(messages.testSentence)
      this.audioStatusTarget.textContent = messages.voiceSuccess
    } catch (_error) {
      this.audioStatusTarget.textContent = messages.voiceError
    }
  }

  async testMicrophone(event) {
    event.preventDefault()
    const messages = this.audioStatusTarget.dataset

    if (!navigator.mediaDevices?.getUserMedia) {
      this.audioStatusTarget.textContent = messages.microphoneError
      return
    }

    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      stream.getTracks().forEach((track) => track.stop())
      this.audioStatusTarget.textContent = messages.microphoneSuccess
    } catch (_error) {
      this.audioStatusTarget.textContent = messages.microphoneError
    }
  }
}
