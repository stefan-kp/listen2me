import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "listen2me:speech-mode"

export default class extends Controller {
  static targets = ["button", "status", "modeLabel"]
  static values = {
    directStatus: { type: String, default: "Satzkarten sprechen sofort." },
    draftStatus: { type: String, default: "Satzkarten werden zuerst ins Textfeld übernommen." }
  }

  connect() {
    this.setMode(this.storedMode(), { announce: false })
  }

  choose(event) {
    this.setMode(event.params.mode)
  }

  setMode(mode, options = {}) {
    this.mode = mode === "draft" ? "draft" : "direct"
    window.localStorage.setItem(STORAGE_KEY, this.mode)

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
    return window.localStorage.getItem(STORAGE_KEY) === "draft" ? "draft" : "direct"
  }
}
