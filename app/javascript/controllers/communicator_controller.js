import { Controller } from "@hotwired/stimulus"
import { isSpeechCancellation, speakText } from "controllers/speech_output"

export default class extends Controller {
  static targets = [
    "input",
    "composerEntry",
    "completed",
    "completedText",
    "completedTime",
    "followups",
    "followupList",
    "recentList",
    "recentEmpty",
    "card",
    "modeHint",
    "status"
  ]
  static values = {
    speakingStatus: { type: String, default: "Wird gesprochen …" },
    readyStatus: { type: String, default: "Bereit" },
    unavailableStatus: { type: String, default: "Sprachausgabe ist in diesem Browser nicht verfügbar." },
    saveErrorStatus: { type: String, default: "Gesprochen, aber nicht gespeichert." },
    spokenAtLabel: { type: String, default: "Gesprochen um" },
    directAction: { type: String, default: "Sofort" },
    draftAction: { type: String, default: "Schreiben" },
    directSuggestionLabel: { type: String, default: "sofort sprechen" },
    draftSuggestionLabel: { type: String, default: "zuerst schreiben" },
    followupRules: Array,
    defaultFollowups: Array
  }

  connect() {
    this.mode = this.storedMode()
    this.lastSpokenText = ""
    this.recents = []
    this.handleModeChange = this.handleModeChange.bind(this)
    window.addEventListener("speech-mode:changed", this.handleModeChange)
    this.updateModeHints()
  }

  disconnect() {
    window.removeEventListener("speech-mode:changed", this.handleModeChange)
  }

  choosePhrase(event) {
    event.preventDefault()
    const text = event.params.text || event.currentTarget.dataset.text
    const urgent = event.params.urgent === true || event.params.urgent === "true"
    const trackUrl = event.params.trackUrl || event.currentTarget.dataset.trackUrl

    if (urgent || this.mode === "direct") {
      this.speakAndComplete(text, { trackUrl })
    } else {
      this.fillComposer(text)
    }
  }

  speakComposer(event) {
    event.preventDefault()
    const form = event.currentTarget.closest("form")
    const input = form?.querySelector("[data-communicator-target='input']")
    const text = input?.value?.trim()

    if (!text) {
      input?.focus()
      return
    }

    this.speakAndComplete(text, {
      saveUrl: event.params.saveUrl,
      categoryId: form?.querySelector("[name='category_id']")?.value
    })
  }

  repeatLast(event) {
    event.preventDefault()
    if (this.lastSpokenText) this.speakAndComplete(this.lastSpokenText)
  }

  editLast(event) {
    event.preventDefault()
    this.fillComposer(this.lastSpokenText)
    this.showComposer()
  }

  newTopic(event) {
    event.preventDefault()
    this.lastSpokenText = ""
    this.showComposer()
    this.followupsTargets.forEach((element) => {
      element.hidden = true
    })
    this.inputTargets.forEach((input) => {
      input.value = ""
    })
    this.inputTargets[0]?.focus()
  }

  async speakAndComplete(text, options = {}) {
    const content = String(text || "").trim()
    if (!content) return

    this.setStatus(this.speakingStatusValue)

    try {
      await speakText(content)
      this.lastSpokenText = content
      this.markComplete(content)
      this.addRecent(content)
      this.renderFollowups(content)
      this.setStatus(this.readyStatusValue)

      if (options.trackUrl) this.trackSentence(options.trackUrl)
      if (options.saveUrl) this.saveSentence(options.saveUrl, content, options.categoryId)
    } catch (error) {
      if (isSpeechCancellation(error)) return

      this.setStatus(this.unavailableStatusValue)
    }
  }

  fillComposer(text) {
    const input = this.inputTargets[0]
    if (!input) return

    input.value = String(text || "")
    input.dispatchEvent(new Event("input", { bubbles: true }))
    input.focus({ preventScroll: true })
  }

  markComplete(text) {
    this.completedTextTargets.forEach((element) => {
      element.textContent = text
    })

    this.completedTimeTargets.forEach((element) => {
      element.textContent = `${this.spokenAtLabelValue} ${new Intl.DateTimeFormat(document.documentElement.lang || "de", {
        hour: "2-digit",
        minute: "2-digit"
      }).format(new Date())}`
    })

    this.completedTargets.forEach((element) => {
      element.hidden = false
    })

    this.composerEntryTargets.forEach((element) => {
      element.hidden = true
    })

    this.completedTargets[0]?.focus({ preventScroll: true })
  }

  showComposer() {
    this.completedTargets.forEach((element) => {
      element.hidden = true
    })

    this.composerEntryTargets.forEach((element) => {
      element.hidden = false
    })
  }

  renderFollowups(text) {
    const normalized = text.toLocaleLowerCase()
    const rule = this.followupRulesValue.find((candidate) =>
      candidate.terms.some((term) => normalized.includes(term))
    )
    const suggestions = rule?.suggestions || this.defaultFollowupsValue

    this.followupListTargets.forEach((list) => {
      list.replaceChildren()

      suggestions.forEach((suggestion) => {
        const button = document.createElement("button")
        const copy = document.createElement("span")
        const action = document.createElement("small")

        button.type = "button"
        button.className = "l2m-suggestion-button"
        button.setAttribute("aria-label", this.mode === "direct"
          ? `${suggestion} ${this.directSuggestionLabelValue}`
          : `${suggestion} ${this.draftSuggestionLabelValue}`)
        copy.textContent = suggestion
        action.textContent = this.mode === "direct" ? this.directActionValue : this.draftActionValue
        button.append(copy, action)
        button.addEventListener("click", () => {
          if (this.mode === "direct") {
            this.speakAndComplete(suggestion)
          } else {
            this.fillComposer(suggestion)
            this.showComposer()
          }
        })
        list.append(button)
      })
    })

    this.followupsTargets.forEach((element) => {
      element.hidden = false
    })
  }

  addRecent(text) {
    this.recents = [text, ...this.recents.filter((item) => item !== text)].slice(0, 5)
    this.renderRecents()
  }

  renderRecents() {
    this.recentEmptyTargets.forEach((element) => {
      element.hidden = this.recents.length > 0
    })

    this.recentListTargets.forEach((list) => {
      list.replaceChildren()
      this.recents.forEach((item) => {
        const row = document.createElement("li")
        const button = document.createElement("button")
        button.type = "button"
        button.textContent = item
        button.setAttribute("aria-label", this.mode === "direct"
          ? `${item} ${this.directSuggestionLabelValue}`
          : `${item} ${this.draftSuggestionLabelValue}`)
        button.addEventListener("click", () => {
          if (this.mode === "direct") {
            this.speakAndComplete(item)
          } else {
            this.fillComposer(item)
            this.showComposer()
          }
        })
        row.append(button)
        list.append(row)
      })
    })
  }

  handleModeChange(event) {
    this.mode = event.detail.mode
    this.updateModeHints()
    if (this.lastSpokenText) this.renderFollowups(this.lastSpokenText)
    this.renderRecents()
  }

  updateModeHints() {
    this.cardTargets.forEach((card) => {
      card.setAttribute("aria-label", this.mode === "direct"
        ? card.dataset.directLabel
        : card.dataset.draftLabel)
    })

    this.modeHintTargets.forEach((element) => {
      element.textContent = this.mode === "direct"
        ? element.dataset.directText
        : element.dataset.draftText
    })
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

  async trackSentence(url) {
    try {
      const response = await fetch(url, {
        method: "POST",
        headers: {
          "X-CSRF-Token": this.csrfToken(),
          "Accept": "application/json"
        }
      })
      if (!response.ok) throw new Error(`HTTP ${response.status}`)
    } catch (_error) {
      // Speech output must remain usable if usage tracking is unavailable.
    }
  }

  async saveSentence(url, content, categoryId) {
    const body = new FormData()
    body.append("content", content)
    if (categoryId) body.append("category_id", categoryId)

    try {
      const response = await fetch(url, {
        method: "POST",
        headers: {
          "X-CSRF-Token": this.csrfToken(),
          "Accept": "application/json"
        },
        body
      })
      if (!response.ok) throw new Error(`HTTP ${response.status}`)
    } catch (_error) {
      this.setStatus(this.saveErrorStatusValue)
    }
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }
}
