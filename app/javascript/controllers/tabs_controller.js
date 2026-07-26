import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { initial: String }

  connect() {
    this.handleHashChange = this.handleHashChange.bind(this)
    window.addEventListener("hashchange", this.handleHashChange)

    const requestedTab = window.location.hash.replace("#", "")
    const fallbackTab = this.hasInitialValue && this.hasTab(this.initialValue)
      ? this.initialValue
      : this.tabTargets[0]?.dataset.tab
    const initialTab = this.hasTab(requestedTab) ? requestedTab : fallbackTab

    this.activate(initialTab, { updateHash: false })
  }

  disconnect() {
    window.removeEventListener("hashchange", this.handleHashChange)
  }

  handleHashChange() {
    const requestedTab = window.location.hash.replace("#", "")
    if (this.hasTab(requestedTab)) this.activate(requestedTab, { updateHash: false })
  }

  switch(event) {
    event.preventDefault()
    const tabName = event.currentTarget.dataset.tab
    this.activate(tabName)
  }

  keydown(event) {
    if (!["ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown", "Home", "End"].includes(event.key)) return

    event.preventDefault()
    const currentIndex = this.tabTargets.indexOf(event.currentTarget)
    const forwards = ["ArrowRight", "ArrowDown"].includes(event.key)
    const nextIndex = event.key === "Home"
      ? 0
      : event.key === "End"
        ? this.tabTargets.length - 1
        : (currentIndex + (forwards ? 1 : -1) + this.tabTargets.length) % this.tabTargets.length
    const nextTab = this.tabTargets[nextIndex]
    this.activate(nextTab.dataset.tab)
    nextTab.focus()
  }

  activate(tabName, { updateHash = true } = {}) {
    if (!tabName) return

    this.hideAllPanels()
    this.showPanel(tabName)
    this.updateTabs(tabName)
    if (updateHash) window.history.replaceState(null, "", `#${tabName}`)
  }

  hasTab(tabName) {
    return this.tabTargets.some((tab) => tab.dataset.tab === tabName)
  }

  hideAllPanels() {
    this.panelTargets.forEach(panel => {
      panel.hidden = true
    })
  }

  showPanel(tabName) {
    const panel = this.panelTargets.find(p => p.dataset.panel === tabName)
    if (panel) {
      panel.hidden = false
    }
  }

  updateTabs(selectedTab) {
    this.tabTargets.forEach(tab => {
      const isSelected = tab.dataset.tab === selectedTab
      tab.setAttribute("aria-selected", String(isSelected))
      tab.tabIndex = isSelected ? 0 : -1
      tab.classList.toggle("is-active", isSelected)
    })
  }
}
