import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "status", "modeLabel"]
  static values = {
    directStatus: { type: String, default: "Satzkarten sprechen sofort." },
    draftStatus: { type: String, default: "Satzkarten werden zuerst ins Textfeld übernommen." },
    initialMode: { type: String, default: "direct" },
    storageKey: String,
    updateUrl: String
  }

  connect() {
    this.setMode(this.storedMode(), { announce: false })
  }

  choose(event) {
    this.setMode(event.params.mode)
    this.persistMode()
  }

  setMode(mode, options = {}) {
    this.mode = mode === "draft" ? "draft" : "direct"
    this.storeMode(this.mode)

    this.buttonTargets.forEach((button) => {
      const active = button.dataset.mode === this.mode
      button.classList.toggle("is-active", active)
      button.setAttribute("aria-pressed", String(active))
    })

    this.modeLabelTargets.forEach((label) => {
      label.textContent = this.mode === "direct" ? label.dataset.directLabel : label.dataset.draftLabel
    })

    const message = this.mode === "direct" ? this.directStatusValue : this.draftStatusValue
    if (options.announce !== false) {
      this.statusTargets.forEach((status) => {
        status.textContent = message
      })
    }

    window.dispatchEvent(new CustomEvent("speech-mode:changed", {
      detail: { mode: this.mode }
    }))
  }

  storedMode() {
    const stored = this.readStoredMode()
    if (stored === "direct" || stored === "draft") return stored

    return this.initialModeValue === "draft" ? "draft" : "direct"
  }

  readStoredMode() {
    if (!this.hasStorageKeyValue) return null

    try {
      return window.localStorage.getItem(this.storageKeyValue)
    } catch (_error) {
      return null
    }
  }

  storeMode(mode) {
    if (!this.hasStorageKeyValue) return

    try {
      window.localStorage.setItem(this.storageKeyValue, mode)
    } catch (_error) {
      // The database-backed preference remains available when storage is blocked.
    }
  }

  persistMode() {
    if (!this.hasUpdateUrlValue) return

    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content
    if (!csrfToken) return

    fetch(this.updateUrlValue, {
      method: "PATCH",
      credentials: "same-origin",
      keepalive: true,
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken
      },
      body: JSON.stringify({ speech_mode: { mode: this.mode } })
    }).catch(() => {
      // Local storage remains a safe per-device fallback when persistence is unavailable.
    })
  }
}
