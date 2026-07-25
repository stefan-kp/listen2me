import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["indicator", "status", "detail", "manualFallback", "toggle"]
  static values = {
    activeStatus: { type: String, default: "Gespräch aktiv" },
    readyStatus: { type: String, default: "Gespräch bereit" },
    stoppedStatus: { type: String, default: "Zuhören pausiert" },
    includedDetail: { type: String, default: "Das Gegenüber wird berücksichtigt." },
    unavailableDetail: { type: String, default: "Mikrofon nicht verfügbar. Partnertext kann unten eingegeben werden." },
    recognizedDetail: { type: String, default: "Beitrag erkannt." },
    listeningPrefix: { type: String, default: "Hört zu:" },
    interruptedDetail: { type: String, default: "Zuhören wurde unterbrochen. Neuer Versuch …" },
    pausedDetail: { type: String, default: "Zuhören pausiert während der Sprachausgabe." },
    userPausedDetail: { type: String, default: "Das Mikrofon ist pausiert." },
    pauseLabel: { type: String, default: "Mikrofon pausieren" },
    resumeLabel: { type: String, default: "Mikrofon wieder einschalten" }
  }

  connect() {
    this.state = "idle"
    this.isConnected = true
    this.shouldListen = true
    this.userPaused = false
    this.pausedForSpeech = false
    this.restartTimer = null
    this.dispatchedFinals = new Set()
    this.pauseForSpeech = this.pauseForSpeech.bind(this)
    this.resumeAfterSpeech = this.resumeAfterSpeech.bind(this)

    window.addEventListener("speech:pauseRecording", this.pauseForSpeech)
    window.addEventListener("speech:resumeRecording", this.resumeAfterSpeech)

    this.setupSpeechRecognition()
    this.updateToggle()
    if (this.recognition) this.startRecording()
  }

  disconnect() {
    this.isConnected = false
    this.shouldListen = false
    window.clearTimeout(this.restartTimer)
    window.removeEventListener("speech:pauseRecording", this.pauseForSpeech)
    window.removeEventListener("speech:resumeRecording", this.resumeAfterSpeech)

    if (this.recognition) {
      try {
        this.recognition.abort()
      } catch (_error) {
        // The recognizer may already be stopped.
      }

      this.recognition.onstart = null
      this.recognition.onresult = null
      this.recognition.onerror = null
      this.recognition.onend = null
      this.recognition = null
    }

    this.state = "disconnected"
  }

  setupSpeechRecognition() {
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition

    if (!SpeechRecognition) {
      this.shouldListen = false
      this.userPaused = true
      this.setUnavailable(this.unavailableDetailValue)
      return
    }

    this.recognition = new SpeechRecognition()
    this.recognition.continuous = true
    this.recognition.interimResults = true
    this.recognition.lang = document.documentElement.lang || "de-DE"

    this.recognition.onstart = () => {
      if (!this.isConnected || !this.shouldListen || this.userPaused || this.pausedForSpeech) {
        try {
          this.recognition?.abort()
        } catch (_error) {
          // The recognizer is already stopping.
        }
        return
      }

      this.state = "listening"
      this.dispatchedFinals.clear()
      this.setActive(true)
      this.setDetail(this.includedDetailValue)
    }

    this.recognition.onresult = (event) => {
      const interim = []
      let recognizedFinal = false

      for (let index = event.resultIndex; index < event.results.length; index += 1) {
        const result = event.results[index]
        const text = result[0]?.transcript?.trim()
        if (!text) continue

        if (result.isFinal) {
          const resultKey = `${index}:${text}`
          if (this.dispatchedFinals.has(resultKey)) continue

          this.dispatchedFinals.add(resultKey)
          recognizedFinal = true
          this.dispatch("transcript", { detail: { text } })
        } else {
          interim.push(text)
        }
      }

      if (interim.length > 0) {
        this.setDetail(`${this.listeningPrefixValue} ${interim.join(" ")}`)
      } else if (recognizedFinal) {
        this.setDetail(this.recognizedDetailValue)
      }
    }

    this.recognition.onerror = (event) => {
      this.state = "idle"

      if (["not-allowed", "service-not-allowed", "audio-capture"].includes(event.error)) {
        this.shouldListen = false
        this.userPaused = true
        this.setUnavailable(this.unavailableDetailValue)
      } else if (event.error !== "aborted" && event.error !== "no-speech") {
        this.setDetail(this.interruptedDetailValue)
      }
    }

    this.recognition.onend = () => {
      if (!this.isConnected) return

      this.state = "idle"
      this.setActive(false)

      if (this.shouldListen && !this.userPaused && !this.pausedForSpeech) {
        window.clearTimeout(this.restartTimer)
        this.restartTimer = window.setTimeout(() => this.startRecording(), 350)
      }
    }
  }

  startRecording() {
    if (
      !this.recognition ||
      !this.isConnected ||
      !this.shouldListen ||
      this.userPaused ||
      this.pausedForSpeech ||
      ["starting", "listening"].includes(this.state)
    ) return

    this.state = "starting"

    try {
      this.recognition.start()
    } catch (_error) {
      this.state = "idle"
    }
  }

  stopRecording() {
    window.clearTimeout(this.restartTimer)

    if (!this.recognition || !["starting", "listening"].includes(this.state)) {
      this.setActive(false)
      return
    }

    this.state = "stopping"
    try {
      this.recognition.abort()
    } catch (_error) {
      this.state = "idle"
    }
    this.setActive(false)
  }

  pauseForSpeech() {
    this.pausedForSpeech = true
    this.stopRecording()
    if (!this.userPaused) this.setDetail(this.pausedDetailValue)
  }

  resumeAfterSpeech() {
    this.pausedForSpeech = false
    if (!this.shouldListen || this.userPaused) return

    this.startRecording()
  }

  toggle(event) {
    event.preventDefault()

    if (this.userPaused || !this.shouldListen) {
      this.userPaused = false
      this.shouldListen = true
      this.setDetail(this.includedDetailValue)
      if (!this.recognition) this.setupSpeechRecognition()
      this.updateToggle()
      this.startRecording()
    } else {
      this.userPaused = true
      this.shouldListen = false
      this.stopRecording()
      this.setDetail(this.userPausedDetailValue)
      this.updateToggle()
    }
  }

  retry(event) {
    event.preventDefault()
    this.userPaused = false
    this.shouldListen = true
    this.pausedForSpeech = false
    if (!this.recognition) this.setupSpeechRecognition()
    this.updateToggle()
    this.startRecording()
  }

  setActive(active) {
    this.indicatorTargets.forEach((indicator) => {
      indicator.classList.toggle("is-active", active)
    })
    this.statusTargets.forEach((status) => {
      status.textContent = active
        ? this.activeStatusValue
        : (this.userPaused ? this.stoppedStatusValue : this.readyStatusValue)
    })
  }

  setDetail(message) {
    this.detailTargets.forEach((detail) => {
      detail.textContent = message
    })
  }

  setUnavailable(message) {
    this.setActive(false)
    this.setDetail(message)
    this.manualFallbackTargets.forEach((element) => {
      element.hidden = false
      if (element.tagName === "DETAILS") element.open = true
    })
    this.updateToggle()
  }

  updateToggle() {
    this.toggleTargets.forEach((button) => {
      const paused = this.userPaused || !this.shouldListen
      button.setAttribute("aria-pressed", String(paused))
      button.textContent = paused ? this.resumeLabelValue : this.pauseLabelValue
    })
  }
}
