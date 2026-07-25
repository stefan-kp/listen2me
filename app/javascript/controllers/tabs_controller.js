import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() {
    const hasApiKey = this.element.dataset.hasApiKey === "true"
    const initialTab = hasApiKey ? "about" : "system"

    this.hideAllPanels()
    this.showPanel(initialTab)
    this.updateTabs(initialTab)
  }

  switch(event) {
    event.preventDefault()
    this.activate(event.currentTarget.dataset.tab)
  }

  keydown(event) {
    if (!["ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key)) return

    event.preventDefault()
    const currentIndex = this.tabTargets.indexOf(event.currentTarget)
    const nextIndex = event.key === "Home"
      ? 0
      : event.key === "End"
        ? this.tabTargets.length - 1
        : (currentIndex + (event.key === "ArrowRight" ? 1 : -1) + this.tabTargets.length) % this.tabTargets.length
    const nextTab = this.tabTargets[nextIndex]
    this.activate(nextTab.dataset.tab)
    nextTab.focus()
  }

  activate(tabName) {
    this.hideAllPanels()
    this.showPanel(tabName)
    this.updateTabs(tabName)
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
      tab.classList.toggle("border-blue-500", isSelected)
      tab.classList.toggle("text-blue-600", isSelected)
      tab.classList.toggle("border-transparent", !isSelected)
      tab.classList.toggle("text-gray-500", !isSelected)
      tab.classList.toggle("hover:text-gray-700", !isSelected)
      tab.classList.toggle("hover:border-gray-300", !isSelected)
    })
  }
}
