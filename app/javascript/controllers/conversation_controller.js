import { Controller } from "@hotwired/stimulus"
import { isSpeechCancellation, speakText } from "controllers/speech_output"

export default class extends Controller {
  static targets = [
    "messages",
    "suggestions",
    "input",
    "partnerInput",
    "status",
    "error",
    "suggestionHelp"
  ]

  static values = {
    conversationId: Number,
    createUrl: String,
    messageUrlTemplate: String,
    suggestionsUrlTemplate: String,
    showUrlTemplate: String,
    fallbackSuggestions: Array,
    refreshSuggestionsOnConnect: Boolean,
    ownLabel: { type: String, default: "Du" },
    partnerLabel: { type: String, default: "Gegenüber" },
    directAction: { type: String, default: "Sofort" },
    draftAction: { type: String, default: "Schreiben" },
    directHelp: { type: String, default: "Ein Tipp spricht die Antwort sofort. Oben kannst du zu „Erst schreiben“ wechseln." },
    draftHelp: { type: String, default: "Ein Tipp übernimmt die Antwort ins Textfeld. Dort kannst du sie ändern und sprechen." },
    preparingStatus: { type: String, default: "Gespräch wird vorbereitet …" },
    activeStatus: { type: String, default: "Gespräch aktiv" },
    speakingStatus: { type: String, default: "Antwort wird gesprochen …" },
    suggestionsStatus: { type: String, default: "Neue Vorschläge werden vorbereitet …" },
    setupError: { type: String, default: "Das Gespräch konnte nicht gestartet werden. Bitte lade die Seite erneut." },
    saveError: { type: String, default: "Der Beitrag konnte nicht gespeichert werden. Du kannst ihn erneut versuchen." },
    speechError: { type: String, default: "Die Sprachausgabe ist in diesem Browser nicht verfügbar." }
  }

  connect() {
    this.mode = this.storedMode()
    this.sessionPromise = null
    this.messageQueue = Promise.resolve()
    this.suggestionRequest = null
    this.suggestionTimer = null
    this.suggestionGeneration = 0
    this.realtimeActive = false
    this.handleModeChange = this.handleModeChange.bind(this)
    window.addEventListener("speech-mode:changed", this.handleModeChange)

    if (this.hasConversationIdValue && this.conversationIdValue > 0) {
      this.markSessionReady()
    } else {
      this.setStatus(this.activeStatusValue)
    }

    this.updateModeHelp()
    this.updateSuggestionActions()

    if (this.refreshSuggestionsOnConnectValue && this.hasConversationIdValue && this.conversationIdValue > 0) {
      this.refreshSuggestions()
    }
  }

  disconnect() {
    window.removeEventListener("speech-mode:changed", this.handleModeChange)
    window.clearTimeout(this.suggestionTimer)
    this.suggestionRequest?.abort()
  }

  async ensureSession() {
    if (this.hasConversationIdValue && this.conversationIdValue > 0) {
      this.markSessionReady()
      return this.conversationIdValue
    }

    if (this.sessionPromise) return this.sessionPromise

    this.setStatus(this.preparingStatusValue)
    this.sessionPromise = fetch(this.createUrlValue, {
      method: "POST",
      headers: {
        "X-CSRF-Token": this.csrfToken(),
        "Content-Type": "application/json",
        "Accept": "application/json"
      },
      body: JSON.stringify({ conversation: {} })
    })
      .then((response) => {
        if (!response.ok) throw new Error(`HTTP ${response.status}`)
        return response.json()
      })
      .then((payload) => {
        this.conversationIdValue = Number(payload.id)
        this.markSessionReady()
        this.replaceUrl()
        return this.conversationIdValue
      })
      .catch(() => {
        this.sessionPromise = null
        this.showError(this.setupErrorValue)
        throw new Error("Conversation setup failed")
      })

    return this.sessionPromise
  }

  async receivePartner(event) {
    event.preventDefault?.()
    const text = event.detail?.text || this.partnerInputTarget?.value
    const content = String(text || "").trim()
    if (!content) return

    const source = event.type === "realtime:transcript" ? "realtime" : "manual"
    const saved = await this.postMessage(content, "partner", source)
    if (saved && this.hasPartnerInputTarget && this.partnerInputTarget.value.trim() === content) {
      this.partnerInputTarget.value = ""
    }
  }

  async speakOwn(event) {
    event.preventDefault()
    const content = this.inputTarget.value.trim()
    if (!content) {
      this.inputTarget.focus()
      return
    }

    await this.speakAndSave(content)
  }

  useSuggestion(event) {
    event.preventDefault()
    const text = String(event.params.text || event.currentTarget.dataset.text || "").trim()
    if (!text) return

    if (this.mode === "direct") {
      this.speakAndSave(text)
    } else {
      this.inputTarget.value = text
      this.inputTarget.dispatchEvent(new Event("input", { bubbles: true }))
      this.inputTarget.focus({ preventScroll: true })
    }
  }

  async speakAndSave(text) {
    this.clearError()
    this.setStatus(this.speakingStatusValue)

    try {
      await speakText(text)
    } catch (error) {
      if (isSpeechCancellation(error)) return false

      this.showError(this.speechErrorValue)
      return false
    }

    const saved = await this.postMessage(text, "speaker", "interface")
    if (saved && this.inputTarget.value.trim() === text) this.inputTarget.value = ""
    return saved
  }

  postMessage(text, role, source) {
    const persist = () => this.persistMessage(text, role, source)
    const result = this.messageQueue.then(persist, persist)
    this.messageQueue = result.then(() => undefined, () => undefined)
    return result
  }

  async persistMessage(text, role, source) {
    this.clearError()

    try {
      const conversationId = await this.ensureSession()
      const url = this.withId(this.messageUrlTemplateValue, conversationId)
      const response = await fetch(url, {
        method: "POST",
        headers: {
          "X-CSRF-Token": this.csrfToken(),
          "Content-Type": "application/json",
          "Accept": "application/json"
        },
        body: JSON.stringify({ content: text, role })
      })

      if (!response.ok) throw new Error(`HTTP ${response.status}`)
      this.appendMessage(text, role)
      if (this.realtimeActive) {
        this.suggestionsTarget.classList.add("is-loading")
        this.setStatus(this.suggestionsStatusValue)
        this.dispatch("message-saved", {
          detail: { text, role, source }
        })
      } else {
        this.refreshSuggestions()
      }
      return true
    } catch (_error) {
      this.showError(this.saveErrorValue)
      return false
    }
  }

  refreshSuggestions() {
    if (this.realtimeActive) return

    const generation = ++this.suggestionGeneration
    window.clearTimeout(this.suggestionTimer)
    this.suggestionRequest?.abort()
    this.suggestionsTarget.classList.add("is-loading")
    this.setStatus(this.suggestionsStatusValue)
    this.suggestionTimer = window.setTimeout(() => this.fetchSuggestions(generation), 300)
  }

  async fetchSuggestions(generation) {
    const url = this.withId(this.suggestionsUrlTemplateValue, this.conversationIdValue)
    this.suggestionRequest = new AbortController()

    try {
      const response = await fetch(url, {
        method: "POST",
        headers: {
          "X-CSRF-Token": this.csrfToken(),
          "Accept": "application/json"
        },
        signal: this.suggestionRequest.signal
      })
      if (!response.ok) throw new Error(`HTTP ${response.status}`)
      const payload = await response.json()
      if (generation === this.suggestionGeneration) this.renderSuggestions(payload.suggestions)
    } catch (error) {
      if (error.name !== "AbortError" && generation === this.suggestionGeneration) {
        this.renderSuggestions(this.fallbackSuggestions())
      }
    } finally {
      if (generation === this.suggestionGeneration) {
        this.suggestionRequest = null
        this.suggestionsTarget.classList.remove("is-loading")
        this.setStatus(this.activeStatusValue)
      }
    }
  }

  renderSuggestions(suggestions) {
    const normalized = Array.from(suggestions || [])
      .map((suggestion) => typeof suggestion === "string" ? suggestion : suggestion?.content)
      .filter(Boolean)
      .slice(0, 3)
    const items = normalized.length === 3 ? normalized : this.fallbackSuggestions()
    const currentButtons = Array.from(this.suggestionsTarget.querySelectorAll("button"))
    const focusedIndex = currentButtons.indexOf(document.activeElement)

    this.suggestionsTarget.replaceChildren()
    const buttons = items.map((suggestion) => {
      const button = document.createElement("button")
      const copy = document.createElement("span")
      const action = document.createElement("small")

      button.type = "button"
      button.className = "l2m-suggestion-button"
      button.dataset.action = "click->conversation#useSuggestion"
      button.dataset.conversationTextParam = suggestion
      copy.textContent = suggestion
      action.textContent = this.mode === "direct" ? this.directActionValue : this.draftActionValue
      button.setAttribute("aria-label", `${suggestion} ${action.textContent}`)
      button.append(copy, action)
      this.suggestionsTarget.append(button)
      return button
    })

    if (focusedIndex >= 0) buttons[Math.min(focusedIndex, buttons.length - 1)]?.focus({ preventScroll: true })
  }

  async prepareRealtime() {
    try {
      await this.ensureSession()
    } catch (_error) {
      // The existing setup error is already visible in the conversation UI.
    }
  }

  enableRealtime() {
    this.realtimeActive = true
    window.clearTimeout(this.suggestionTimer)
    this.suggestionRequest?.abort()
    this.suggestionRequest = null
    this.suggestionsTarget.classList.remove("is-loading")
    this.setStatus(this.activeStatusValue)
  }

  disableRealtime() {
    const wasActive = this.realtimeActive
    this.realtimeActive = false
    if (wasActive && this.hasConversationIdValue && this.conversationIdValue > 0) {
      this.refreshSuggestions()
    }
  }

  receiveRealtimeSuggestions(event) {
    if (!this.realtimeActive) return

    this.renderSuggestions(event.detail?.suggestions)
    this.suggestionsTarget.classList.remove("is-loading")
    this.setStatus(this.activeStatusValue)
  }

  appendMessage(text, role) {
    const article = document.createElement("article")
    const label = document.createElement("span")
    const copy = document.createElement("p")

    article.className = role === "speaker"
      ? "l2m-message l2m-message-own"
      : "l2m-message l2m-message-partner"
    label.textContent = role === "speaker" ? this.ownLabelValue : this.partnerLabelValue
    copy.textContent = text
    article.append(label, copy)
    this.messagesTarget.querySelector(".l2m-empty-state")?.remove()
    this.messagesTarget.append(article)
    article.scrollIntoView({ block: "nearest", behavior: "smooth" })
  }

  handleModeChange(event) {
    this.mode = event.detail.mode
    this.updateModeHelp()

    const current = Array.from(this.suggestionsTarget.querySelectorAll("button span:first-child"))
      .map((element) => element.textContent)
    if (current.length) this.renderSuggestions(current)
  }

  updateModeHelp() {
    if (!this.hasSuggestionHelpTarget) return

    this.suggestionHelpTarget.textContent = this.mode === "direct"
      ? this.directHelpValue
      : this.draftHelpValue
    this.updateSuggestionActions()
  }

  updateSuggestionActions() {
    this.suggestionsTarget.querySelectorAll("button").forEach((button) => {
      const action = button.querySelector("small")
      const suggestion = button.querySelector("span")?.textContent
      if (!action) return

      action.textContent = this.mode === "direct" ? this.directActionValue : this.draftActionValue
      button.setAttribute("aria-label", `${suggestion} ${action.textContent}`)
    })
  }

  markSessionReady() {
    this.element.dataset.conversationReady = "true"
    this.setStatus(this.activeStatusValue)
    this.element.dispatchEvent(new CustomEvent("conversation:ready", {
      bubbles: true,
      detail: { id: this.conversationIdValue }
    }))
  }

  replaceUrl() {
    if (!this.hasShowUrlTemplateValue) return
    window.history.replaceState(
      window.history.state,
      "",
      this.withId(this.showUrlTemplateValue, this.conversationIdValue)
    )
  }

  withId(template, id) {
    return template.replace("__ID__", String(id))
  }

  storedMode() {
    const fallback = document.body.dataset.speechModeInitialModeValue === "draft" ? "draft" : "direct"
    const storageKey = document.body.dataset.speechModeStorageKeyValue
    if (!storageKey) return fallback

    try {
      const stored = window.localStorage.getItem(storageKey)
      return stored === "direct" || stored === "draft" ? stored : fallback
    } catch (_error) {
      return fallback
    }
  }

  setStatus(message) {
    this.statusTargets.forEach((element) => {
      element.textContent = message
    })
  }

  showError(message) {
    if (this.hasErrorTarget) {
      this.errorTarget.hidden = false
      this.errorTarget.textContent = message
    }
    this.setStatus(message)
  }

  clearError() {
    if (!this.hasErrorTarget) return

    this.errorTarget.hidden = true
    this.errorTarget.textContent = ""
  }

  fallbackSuggestions() {
    return this.hasFallbackSuggestionsValue && this.fallbackSuggestionsValue.length === 3
      ? this.fallbackSuggestionsValue
      : []
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }
}
