import { Controller } from "@hotwired/stimulus"

const SUGGESTION_TOOL_NAME = "show_reply_suggestions"

export default class extends Controller {
  static targets = ["status", "detail", "button"]

  static values = {
    available: Boolean,
    conversationId: Number,
    callUrlTemplate: String,
    suggestionPrompt: String,
    standardStatus: { type: String, default: "Standardmodus" },
    standardDetail: { type: String, default: "Browsererkennung mit sicherem Fallback." },
    connectingStatus: { type: String, default: "Live-KI verbindet …" },
    connectingDetail: { type: String, default: "Mikrofon und schnelle Vorschläge werden vorbereitet." },
    liveStatus: { type: String, default: "Live-KI aktiv" },
    liveDetail: { type: String, default: "Das Gespräch wird laufend berücksichtigt." },
    unavailableStatus: { type: String, default: "Standardmodus aktiv" },
    unavailableDetail: { type: String, default: "Live-KI war nicht erreichbar. Die normale Erkennung läuft weiter." },
    startLabel: { type: String, default: "Live-KI testen" },
    stopLabel: { type: String, default: "Live-KI beenden" }
  }

  connect() {
    this.active = false
    this.connecting = false
    this.userPaused = false
    this.generation = 0
    this.seenTranscriptItems = new Set()
    this.conversationWaiter = null
    this.pauseForSpeech = this.pauseForSpeech.bind(this)
    this.resumeAfterSpeech = this.resumeAfterSpeech.bind(this)
    window.addEventListener("speech:pauseRecording", this.pauseForSpeech)
    window.addEventListener("speech:resumeRecording", this.resumeAfterSpeech)
    this.renderStandard()
  }

  disconnect() {
    window.removeEventListener("speech:pauseRecording", this.pauseForSpeech)
    window.removeEventListener("speech:resumeRecording", this.resumeAfterSpeech)
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
      const conversationId = await this.ensureConversation()
      this.stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      this.microphoneTrack = this.stream.getAudioTracks()[0]
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
        }
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

  messageSaved(event) {
    if (!this.active || this.dataChannel?.readyState !== "open") return

    const { text, role, source } = event.detail || {}
    if (source !== "realtime") {
      this.send({
        type: "conversation.item.create",
        item: {
          type: "message",
          role: "user",
          content: [{
            type: "input_text",
            text: `[${role === "speaker" ? "speaker" : "partner"}] ${text}`
          }]
        }
      })
    }

    this.requestSuggestions()
  }

  listeningChanged(event) {
    this.userPaused = event.detail?.paused === true
    this.updateMicrophone()
  }

  pauseForSpeech() {
    if (!this.active || !this.microphoneTrack) return
    this.microphoneTrack.enabled = false
  }

  resumeAfterSpeech() {
    if (!this.active || !this.microphoneTrack) return
    this.updateMicrophone()
  }

  receiveEvent(message) {
    let event
    try {
      event = JSON.parse(message.data)
    } catch (_error) {
      return
    }

    if (event.type === "conversation.item.input_audio_transcription.completed") {
      this.receiveTranscript(event)
    } else if (event.type === "response.done") {
      this.receiveSuggestions(event)
    } else if (event.type === "error") {
      this.handleConnectionLoss()
    }
  }

  receiveTranscript(event) {
    const itemId = String(event.item_id || "")
    const text = String(event.transcript || "").trim()
    if (!itemId || !text || this.seenTranscriptItems.has(itemId)) return

    this.seenTranscriptItems.add(itemId)
    this.dispatch("transcript", { detail: { text, source: "realtime" } })
  }

  requestSuggestions() {
    const generation = ++this.generation
    this.send({
      type: "response.create",
      response: {
        conversation: "none",
        metadata: {
          purpose: "listen2me_suggestions",
          generation: String(generation)
        },
        output_modalities: ["text"],
        instructions: this.suggestionPromptValue,
        max_output_tokens: 240,
        tools: [{
          type: "function",
          name: SUGGESTION_TOOL_NAME,
          description: "Show exactly three short possible replies for the Listen2Me user.",
          parameters: {
            type: "object",
            properties: {
              suggestions: {
                type: "array",
                minItems: 3,
                maxItems: 3,
                items: { type: "string", maxLength: 140 }
              }
            },
            required: ["suggestions"],
            additionalProperties: false
          }
        }],
        tool_choice: {
          type: "function",
          name: SUGGESTION_TOOL_NAME
        }
      }
    })
  }

  receiveSuggestions(event) {
    const response = event.response
    if (
      response?.status !== "completed" ||
      response.metadata?.purpose !== "listen2me_suggestions" ||
      Number(response.metadata?.generation) !== this.generation
    ) return

    const toolCall = Array.from(response.output || []).find((item) =>
      item.type === "function_call" && item.name === SUGGESTION_TOOL_NAME
    )
    let parsed
    try {
      parsed = JSON.parse(toolCall?.arguments || "{}")
    } catch (_error) {
      parsed = {}
    }

    const suggestions = this.normalizeSuggestions(parsed.suggestions)
    this.dispatch("suggestions", { detail: { suggestions } })
  }

  normalizeSuggestions(suggestions) {
    const normalized = Array.from(suggestions || [])
      .map((suggestion) => String(suggestion || "").trim())
      .filter(Boolean)
      .filter((suggestion, index, all) => all.indexOf(suggestion) === index)
      .slice(0, 3)

    return normalized.length === 3 ? normalized : []
  }

  markReady() {
    if (!this.dataChannel || this.dataChannel.readyState !== "open") return

    this.active = true
    this.connecting = false
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
    this.cancelConversationWaiter()
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
    if (this.microphoneTrack) this.microphoneTrack.enabled = !this.userPaused
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

  send(payload) {
    if (this.dataChannel?.readyState === "open") {
      this.dataChannel.send(JSON.stringify(payload))
    }
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }
}
