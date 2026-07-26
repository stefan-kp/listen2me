import { Controller } from "@hotwired/stimulus"

const MAX_SESSION_MILLISECONDS = 5 * 60 * 1000

export default class extends Controller {
  static targets = ["status", "detail", "button"]

  static values = {
    available: Boolean,
    conversationId: Number,
    callUrlTemplate: String,
    standardStatus: { type: String, default: "Standardmodus" },
    standardDetail: { type: String, default: "Browsererkennung mit sicherem Fallback." },
    connectingStatus: { type: String, default: "Live-Transkription verbindet …" },
    connectingDetail: { type: String, default: "Die bessere Spracherkennung wird vorbereitet." },
    liveStatus: { type: String, default: "Live-Transkription bereit" },
    liveDetail: { type: String, default: "Nach deiner Antwort wird die reale Stimme des Gegenübers transkribiert." },
    unavailableStatus: { type: String, default: "Standardmodus aktiv" },
    unavailableDetail: { type: String, default: "Live-Transkription war nicht erreichbar. Die normale Erkennung läuft weiter." },
    startLabel: { type: String, default: "Live-Transkription starten" },
    stopLabel: { type: String, default: "Live-Transkription beenden" }
  }

  connect() {
    this.active = false
    this.connecting = false
    this.userPaused = false
    this.awaitingPartner = false
    this.transcribing = false
    this.partialTranscript = ""
    this.seenTranscriptItems = new Set()
    this.conversationWaiter = null
    this.connectionController = null
    this.connectionTimer = null
    this.sessionTimer = null
    this.pauseForSpeech = this.pauseForSpeech.bind(this)
    this.resumeAfterSpeech = this.resumeAfterSpeech.bind(this)
    this.finishSpeech = this.finishSpeech.bind(this)
    this.failSpeech = this.failSpeech.bind(this)
    window.addEventListener("speech:pauseRecording", this.pauseForSpeech)
    window.addEventListener("speech:resumeRecording", this.resumeAfterSpeech)
    window.addEventListener("speech:finished", this.finishSpeech)
    window.addEventListener("speech:failed", this.failSpeech)
    this.renderStandard()
  }

  disconnect() {
    window.removeEventListener("speech:pauseRecording", this.pauseForSpeech)
    window.removeEventListener("speech:resumeRecording", this.resumeAfterSpeech)
    window.removeEventListener("speech:finished", this.finishSpeech)
    window.removeEventListener("speech:failed", this.failSpeech)
    this.cleanup({ notify: false })
  }

  toggle(event) {
    event.preventDefault()
    if (this.active || this.connecting) {
      this.cleanup()
      this.renderStandard()
    } else {
      this.start()
    }
  }

  async start() {
    if (
      !this.availableValue ||
      this.connecting ||
      this.active ||
      !window.RTCPeerConnection ||
      !navigator.mediaDevices?.getUserMedia
    ) return

    this.connecting = true
    this.renderState(this.connectingStatusValue, this.connectingDetailValue)
    this.buttonTarget.disabled = true

    try {
      this.stream = await navigator.mediaDevices.getUserMedia({
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true
        },
        video: false
      })
      this.microphoneTrack = this.stream.getAudioTracks()[0]
      if (this.microphoneTrack) this.microphoneTrack.enabled = false
      const conversationId = await this.ensureConversation()
      this.connectionController = new AbortController()
      this.connectionTimer = window.setTimeout(() => {
        this.connectionController?.abort()
        this.handleConnectionLoss()
      }, 10_000)
      this.peerConnection = new RTCPeerConnection()
      this.microphoneTrack && this.peerConnection.addTrack(this.microphoneTrack, this.stream)

      this.dataChannel = this.peerConnection.createDataChannel("oai-events")
      this.dataChannel.addEventListener("open", () => this.markReady())
      this.dataChannel.addEventListener("message", (message) => this.receiveEvent(message))
      this.dataChannel.addEventListener("close", () => this.handleConnectionLoss())
      this.peerConnection.addEventListener("connectionstatechange", () => {
        if (["failed", "closed"].includes(this.peerConnection?.connectionState)) {
          this.handleConnectionLoss()
        }
      })

      const offer = await this.peerConnection.createOffer()
      await this.peerConnection.setLocalDescription(offer)

      const response = await fetch(this.callUrl(conversationId), {
        method: "POST",
        body: offer.sdp,
        headers: {
          "X-CSRF-Token": this.csrfToken(),
          "Content-Type": "application/sdp",
          "Accept": "application/sdp"
        },
        signal: this.connectionController.signal
      })
      if (!response.ok) throw new Error(`HTTP ${response.status}`)

      await this.peerConnection.setRemoteDescription({
        type: "answer",
        sdp: await response.text()
      })
    } catch (_error) {
      this.cleanup()
      this.renderState(this.unavailableStatusValue, this.unavailableDetailValue)
    } finally {
      this.connecting = false
      if (this.hasButtonTarget) this.buttonTarget.disabled = false
    }
  }

  conversationReady(event) {
    const id = Number(event.detail?.id)
    if (!id) return

    this.conversationIdValue = id
    this.conversationWaiter?.resolve(id)
    this.clearConversationWaiter()
  }

  listeningChanged(event) {
    this.userPaused = event.detail?.paused === true
    if (this.userPaused) {
      this.awaitingPartner = false
      this.transcribing = false
    } else if (event.detail?.listening === true) {
      this.awaitingPartner = true
      this.transcribing = false
      this.partialTranscript = ""
    }
    this.updateMicrophone()
  }

  pauseForSpeech() {
    if (!this.active && !this.connecting) return

    this.awaitingPartner = false
    this.transcribing = false
    this.partialTranscript = ""
    this.updateMicrophone()
  }

  resumeAfterSpeech() {
    this.updateMicrophone()
  }

  finishSpeech() {
    if ((!this.active && !this.connecting) || this.userPaused) return

    this.awaitingPartner = true
    this.transcribing = false
    this.partialTranscript = ""
    this.updateMicrophone()
  }

  failSpeech() {
    if (!this.active && !this.connecting) return

    this.awaitingPartner = false
    this.transcribing = false
    this.partialTranscript = ""
    this.updateMicrophone()
  }

  receiveEvent(message) {
    let event
    try {
      event = JSON.parse(message.data)
    } catch (_error) {
      return
    }

    if (event.type === "input_audio_buffer.speech_started") {
      this.receiveSpeechStarted()
    } else if (event.type === "input_audio_buffer.speech_stopped") {
      this.receiveSpeechStopped()
    } else if (event.type === "conversation.item.input_audio_transcription.delta") {
      this.receiveTranscriptDelta(event)
    } else if (event.type === "conversation.item.input_audio_transcription.completed") {
      this.receiveTranscript(event)
    } else if (event.type === "conversation.item.input_audio_transcription.failed") {
      this.retryPartnerTurn()
    } else if (event.type === "error") {
      this.handleConnectionLoss()
    }
  }

  receiveSpeechStarted() {
    if (!this.awaitingPartner) return

    this.transcribing = false
    this.dispatch("speech-started")
  }

  receiveSpeechStopped() {
    if (!this.awaitingPartner) return

    this.transcribing = true
    this.updateMicrophone()
    this.dispatch("transcribing")
  }

  receiveTranscriptDelta(event) {
    if (!this.awaitingPartner) return

    this.partialTranscript += String(event.delta || "")
    const text = this.partialTranscript.trim()
    if (text) this.dispatch("partial", { detail: { text } })
  }

  receiveTranscript(event) {
    const itemId = String(event.item_id || "")
    const text = String(event.transcript || "").trim()
    if (!this.awaitingPartner || (itemId && this.seenTranscriptItems.has(itemId))) return

    if (!text) {
      this.retryPartnerTurn()
      return
    }

    if (itemId) this.seenTranscriptItems.add(itemId)
    this.awaitingPartner = false
    this.transcribing = false
    this.partialTranscript = ""
    this.updateMicrophone()
    this.dispatch("transcript", { detail: { text, source: "realtime" } })
  }

  retryPartnerTurn() {
    if (!this.awaitingPartner) return

    this.transcribing = false
    this.partialTranscript = ""
    this.updateMicrophone()
    this.dispatch("retry")
  }

  stopPartnerTurn() {
    this.awaitingPartner = false
    this.transcribing = false
    this.partialTranscript = ""
    this.updateMicrophone()
  }

  markReady() {
    if (!this.dataChannel || this.dataChannel.readyState !== "open") return

    window.clearTimeout(this.connectionTimer)
    this.connectionTimer = null
    this.connectionController = null
    this.sessionTimer = window.setTimeout(() => {
      this.cleanup()
      this.renderStandard()
    }, MAX_SESSION_MILLISECONDS)
    this.active = true
    this.connecting = false
    this.transcribing = false
    this.updateMicrophone()
    this.renderState(this.liveStatusValue, this.liveDetailValue)
    this.buttonTarget.disabled = false
    this.buttonTarget.textContent = this.stopLabelValue
    this.dispatch("ready")
  }

  handleConnectionLoss() {
    if (!this.active && !this.connecting) return

    this.cleanup()
    this.renderState(this.unavailableStatusValue, this.unavailableDetailValue)
  }

  cleanup({ notify = true } = {}) {
    const shouldNotify = notify && (this.active || this.connecting)
    this.active = false
    this.connecting = false
    this.awaitingPartner = false
    this.transcribing = false
    this.partialTranscript = ""
    this.cancelConversationWaiter()
    window.clearTimeout(this.connectionTimer)
    this.connectionTimer = null
    window.clearTimeout(this.sessionTimer)
    this.sessionTimer = null
    this.connectionController?.abort()
    this.connectionController = null
    this.dataChannel?.close()
    this.peerConnection?.close()
    this.stream?.getTracks().forEach((track) => track.stop())
    this.dataChannel = null
    this.peerConnection = null
    this.stream = null
    this.microphoneTrack = null
    this.seenTranscriptItems.clear()
    if (this.hasButtonTarget) {
      this.buttonTarget.disabled = false
      this.buttonTarget.textContent = this.startLabelValue
    }
    if (shouldNotify) this.dispatch("fallback")
  }

  ensureConversation() {
    if (this.hasConversationIdValue && this.conversationIdValue > 0) {
      return Promise.resolve(this.conversationIdValue)
    }

    return new Promise((resolve, reject) => {
      const timer = window.setTimeout(() => {
        this.clearConversationWaiter()
        reject(new Error("Conversation setup timed out"))
      }, 10000)
      this.conversationWaiter = { resolve, reject, timer }
      this.dispatch("prepare")
    })
  }

  clearConversationWaiter() {
    if (!this.conversationWaiter) return
    window.clearTimeout(this.conversationWaiter.timer)
    this.conversationWaiter = null
  }

  cancelConversationWaiter() {
    this.conversationWaiter?.reject(new Error("Conversation setup cancelled"))
    this.clearConversationWaiter()
  }

  updateMicrophone() {
    if (this.microphoneTrack) {
      this.microphoneTrack.enabled = this.active && this.awaitingPartner && !this.transcribing && !this.userPaused
    }
  }

  renderStandard() {
    this.renderState(this.standardStatusValue, this.standardDetailValue)
    if (this.hasButtonTarget) this.buttonTarget.textContent = this.startLabelValue
  }

  renderState(status, detail) {
    this.statusTargets.forEach((element) => {
      element.textContent = status
    })
    this.detailTargets.forEach((element) => {
      element.textContent = detail
    })
  }

  callUrl(id) {
    return this.callUrlTemplateValue.replace("__ID__", String(id))
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }
}
