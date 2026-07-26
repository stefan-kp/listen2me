import { Controller } from "@hotwired/stimulus"

const FINAL_TRANSCRIPT_PAUSE_MILLISECONDS = 900

export default class extends Controller {
  static targets = ["indicator", "status", "detail", "manualFallback", "toggle"]
  static values = {
    listeningStatus: { type: String, default: "Hört dem Gegenüber zu" },
    readyStatus: { type: String, default: "Bereit für deine Antwort" },
    transcribingStatus: { type: String, default: "Sprache wird erkannt …" },
    stoppedStatus: { type: String, default: "Zuhören pausiert" },
    readyDetail: { type: String, default: "Nach deiner gesprochenen Antwort öffnet sich das Mikrofon automatisch." },
    includedDetail: { type: String, default: "Das Mikrofon ist offen. Jetzt spricht dein Gegenüber." },
    unavailableDetail: { type: String, default: "Mikrofon nicht verfügbar. Der Beitrag kann unten als Text eingegeben werden." },
    recognizedDetail: { type: String, default: "Aussage erkannt. Neue Vorschläge werden vorbereitet." },
    listeningPrefix: { type: String, default: "Hört zu:" },
    interruptedDetail: { type: String, default: "Zuhören wurde unterbrochen. Neuer Versuch …" },
    pausedDetail: { type: String, default: "Deine Antwort wird gesprochen. Danach öffnet sich das Mikrofon." },
    userPausedDetail: { type: String, default: "Das Mikrofon ist pausiert." },
    retryDetail: { type: String, default: "Keine Aussage erkannt. Das Mikrofon hört weiter zu." },
    startLabel: { type: String, default: "Jetzt zuhören" },
    pauseLabel: { type: String, default: "Zuhören pausieren" },
    resumeLabel: { type: String, default: "Zuhören fortsetzen" },
    transcribingLabel: { type: String, default: "Wird transkribiert …" }
  }

  connect() {
    this.state = "idle"
    this.isConnected = true
    this.shouldListen = false
    this.userPaused = false
    this.pausedForSpeech = false
    this.realtimeActive = false
    this.microphoneUnavailable = false
    this.restartTimer = null
    this.finalTranscriptTimer = null
    this.finalTranscriptParts = []
    this.recognitionGeneration = 0
    this.processingPartner = false
    this.dispatchedFinals = new Set()
    this.pauseForSpeech = this.pauseForSpeech.bind(this)
    this.resumeAfterSpeech = this.resumeAfterSpeech.bind(this)
    this.finishSpeech = this.finishSpeech.bind(this)
    this.failSpeech = this.failSpeech.bind(this)

    window.addEventListener("speech:pauseRecording", this.pauseForSpeech)
    window.addEventListener("speech:resumeRecording", this.resumeAfterSpeech)
    window.addEventListener("speech:finished", this.finishSpeech)
    window.addEventListener("speech:failed", this.failSpeech)

    this.setupSpeechRecognition()
    if (!this.microphoneUnavailable) this.setStandby()
  }

  disconnect() {
    this.isConnected = false
    this.shouldListen = false
    window.clearTimeout(this.restartTimer)
    this.clearFinalTranscript()
    window.removeEventListener("speech:pauseRecording", this.pauseForSpeech)
    window.removeEventListener("speech:resumeRecording", this.resumeAfterSpeech)
    window.removeEventListener("speech:finished", this.finishSpeech)
    window.removeEventListener("speech:failed", this.failSpeech)

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
      this.microphoneUnavailable = true
      this.setUnavailable(this.unavailableDetailValue)
      return
    }

    this.microphoneUnavailable = false
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
      this.recognitionGeneration += 1
      this.setListening(true)
    }

    this.recognition.onresult = (event) => {
      if (!this.shouldListen) return

      const interim = []
      const final = []

      for (let index = event.resultIndex; index < event.results.length; index += 1) {
        const result = event.results[index]
        const text = result[0]?.transcript?.trim()
        if (!text) continue

        if (result.isFinal) {
          const resultKey = `${this.recognitionGeneration}:${index}:${text}`
          if (this.dispatchedFinals.has(resultKey)) continue

          this.dispatchedFinals.add(resultKey)
          final.push(text)
        } else {
          interim.push(text)
        }
      }

      if (final.length > 0) this.finalTranscriptParts.push(...final)

      const recognized = [...this.finalTranscriptParts, ...interim].join(" ").trim()
      if (recognized) {
        this.setDetail(`${this.listeningPrefixValue} ${recognized}`)
        this.scheduleFinalTranscript()
      }
    }

    this.recognition.onerror = (event) => {
      this.state = "idle"

      if (["not-allowed", "service-not-allowed", "audio-capture"].includes(event.error)) {
        this.shouldListen = false
        this.microphoneUnavailable = true
        this.setUnavailable(this.unavailableDetailValue)
      } else if (event.error !== "aborted" && event.error !== "no-speech") {
        this.setDetail(this.interruptedDetailValue)
      }
    }

    this.recognition.onend = () => {
      if (!this.isConnected) return

      this.state = "idle"
      this.setIndicator(false)

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
    this.setStatus(this.listeningStatusValue)
    this.setDetail(this.includedDetailValue)
    this.updateToggle()

    try {
      this.recognition.start()
    } catch (_error) {
      this.state = "idle"
    }
  }

  stopRecording() {
    window.clearTimeout(this.restartTimer)

    if (!this.recognition || !["starting", "listening"].includes(this.state)) {
      this.setIndicator(false)
      return
    }

    this.state = "stopping"
    try {
      this.recognition.abort()
    } catch (_error) {
      this.state = "idle"
    }
    this.setIndicator(false)
  }

  pauseForSpeech() {
    this.pausedForSpeech = true
    this.shouldListen = false
    this.processingPartner = false
    this.clearFinalTranscript()
    this.stopRecording()
    this.setStatus(this.readyStatusValue)
    if (!this.userPaused) this.setDetail(this.pausedDetailValue)
    this.updateToggle()
  }

  resumeAfterSpeech() {
    this.pausedForSpeech = false
  }

  finishSpeech() {
    this.pausedForSpeech = false
    if (!this.userPaused) this.beginPartnerTurn()
  }

  failSpeech() {
    this.pausedForSpeech = false
    this.shouldListen = false
    this.processingPartner = false
    this.clearFinalTranscript()
    if (!this.userPaused) this.setStandby()
  }

  beginPartnerTurn() {
    if (!this.isConnected || this.userPaused) return

    this.clearFinalTranscript()
    this.dispatchedFinals.clear()
    this.processingPartner = false
    this.shouldListen = true
    this.microphoneUnavailable = false
    this.setStatus(this.listeningStatusValue)
    this.setDetail(this.includedDetailValue)
    this.updateToggle()

    if (this.realtimeActive) {
      this.setListening(true)
      this.dispatch("listening", { detail: { paused: false, listening: true } })
      return
    }

    if (!this.recognition) this.setupSpeechRecognition()
    if (!this.recognition) return

    this.startRecording()
  }

  completePartnerTurn(text) {
    const content = String(text || "").trim()
    if (!content || !this.shouldListen) return

    this.shouldListen = false
    this.processingPartner = false
    this.clearFinalTranscript()
    this.stopRecording()
    this.setStatus(this.transcribingStatusValue)
    this.setDetail(this.recognizedDetailValue)
    this.updateToggle()
    this.dispatch("transcript", { detail: { text: content, source: "browser" } })
  }

  receivePartial(event) {
    if (!this.realtimeActive || !this.shouldListen) return

    const text = String(event.detail?.text || "").trim()
    if (text) this.setDetail(`${this.listeningPrefixValue} ${text}`)
  }

  partnerSpeechStarted() {
    if (!this.realtimeActive || !this.shouldListen) return

    this.setListening(true)
  }

  transcribing() {
    if (!this.realtimeActive || !this.shouldListen) return

    this.processingPartner = true
    this.setIndicator(false)
    this.setStatus(this.transcribingStatusValue)
    this.updateToggle()
  }

  partnerReceived() {
    if (!this.realtimeActive) return

    this.shouldListen = false
    this.processingPartner = false
    this.setIndicator(false)
    this.setStatus(this.transcribingStatusValue)
    this.setDetail(this.recognizedDetailValue)
    this.updateToggle()
  }

  toggle(event) {
    event.preventDefault()

    if (this.shouldListen && !this.userPaused) {
      this.userPaused = true
      this.shouldListen = false
      this.processingPartner = false
      this.clearFinalTranscript()
      this.stopRecording()
      this.setStatus(this.stoppedStatusValue)
      this.setDetail(this.userPausedDetailValue)
      this.updateToggle()
      this.dispatch("listening", { detail: { paused: true, listening: false } })
      return
    }

    this.userPaused = false
    this.beginPartnerTurn()
  }

  suspendForRealtime() {
    const continueListening = this.shouldListen && !this.userPaused
    this.realtimeActive = true
    this.stopRecording()
    this.shouldListen = continueListening

    if (continueListening) {
      this.setListening(true)
      this.dispatch("listening", { detail: { paused: false, listening: true } })
    } else {
      this.setStandby()
    }
  }

  resumeAfterRealtime() {
    if (!this.realtimeActive) return

    const continueListening = this.shouldListen && !this.userPaused
    this.realtimeActive = false
    if (continueListening) {
      if (!this.recognition) this.setupSpeechRecognition()
      this.startRecording()
    } else if (!this.userPaused) {
      this.setStandby()
    }
  }

  retry(event) {
    event.preventDefault()
    this.userPaused = false
    this.pausedForSpeech = false
    this.microphoneUnavailable = false
    if (!this.recognition) this.setupSpeechRecognition()
    this.beginPartnerTurn()
  }

  retryPartnerTurn() {
    if (!this.realtimeActive || !this.shouldListen) return

    this.processingPartner = false
    this.setListening(true)
    this.setDetail(this.retryDetailValue)
    this.updateToggle()
  }

  stopPartnerTurn() {
    this.shouldListen = false
    this.processingPartner = false
    this.clearFinalTranscript()
    this.stopRecording()
    this.setIndicator(false)
    this.setStatus(this.transcribingStatusValue)
    this.setDetail(this.recognizedDetailValue)
    this.updateToggle()
  }

  scheduleFinalTranscript() {
    window.clearTimeout(this.finalTranscriptTimer)
    this.finalTranscriptTimer = window.setTimeout(() => {
      const transcript = this.finalTranscriptParts.join(" ").trim()
      this.finalTranscriptTimer = null
      if (transcript) this.completePartnerTurn(transcript)
    }, FINAL_TRANSCRIPT_PAUSE_MILLISECONDS)
  }

  clearFinalTranscript() {
    window.clearTimeout(this.finalTranscriptTimer)
    this.finalTranscriptTimer = null
    this.finalTranscriptParts = []
  }

  setStandby() {
    this.shouldListen = false
    this.processingPartner = false
    this.setIndicator(false)
    this.setStatus(this.readyStatusValue)
    this.setDetail(this.readyDetailValue)
    this.updateToggle()
  }

  setListening(active) {
    this.setIndicator(active)
    this.setStatus(active ? this.listeningStatusValue : this.readyStatusValue)
    if (active) this.setDetail(this.includedDetailValue)
  }

  setIndicator(active) {
    this.indicatorTargets.forEach((indicator) => {
      indicator.classList.toggle("is-active", active)
    })
  }

  setStatus(message) {
    this.statusTargets.forEach((status) => {
      status.textContent = message
    })
  }

  setDetail(message) {
    this.detailTargets.forEach((detail) => {
      detail.textContent = message
    })
  }

  setUnavailable(message) {
    this.shouldListen = false
    this.processingPartner = false
    this.clearFinalTranscript()
    this.setIndicator(false)
    this.setStatus(this.readyStatusValue)
    this.setDetail(message)
    this.manualFallbackTargets.forEach((element) => {
      element.hidden = false
      if (element.tagName === "DETAILS") element.open = true
    })
    this.updateToggle()
  }

  updateToggle() {
    this.toggleTargets.forEach((button) => {
      const listening = this.shouldListen && !this.userPaused
      button.disabled = this.processingPartner || (this.microphoneUnavailable && !this.realtimeActive)
      button.setAttribute("aria-pressed", String(listening && !this.processingPartner))

      if (this.processingPartner) {
        button.textContent = this.transcribingLabelValue
      } else if (listening) {
        button.textContent = this.pauseLabelValue
      } else if (this.userPaused) {
        button.textContent = this.resumeLabelValue
      } else {
        button.textContent = this.startLabelValue
      }
    })
  }
}
