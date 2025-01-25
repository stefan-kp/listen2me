import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() {
    // Set initial state based on elevenlabs_api_key
    const hasApiKey = this.element.dataset.hasApiKey === "true"
    const initialTab = hasApiKey ? "about" : "system"
    console.log("hasApiKey:", hasApiKey, "initialTab:", initialTab) // Debug-Log
    
    // Initially hide all panels
    this.hideAllPanels()
    
    // Show initial panel
    this.showPanel(initialTab)
    this.updateTabs(initialTab)
  }

  switch(event) {
    event.preventDefault()
    const tabName = event.currentTarget.dataset.tab
    
    this.hideAllPanels()
    this.showPanel(tabName)
    this.updateTabs(tabName)
  }

  hideAllPanels() {
    this.panelTargets.forEach(panel => {
      panel.style.display = 'none'
    })
  }

  showPanel(tabName) {
    const panel = this.panelTargets.find(p => p.dataset.panel === tabName)
    if (panel) {
      panel.style.display = 'block'
    }
  }

  updateTabs(selectedTab) {
    this.tabTargets.forEach(tab => {
      const isSelected = tab.dataset.tab === selectedTab
      tab.classList.toggle("border-blue-500", isSelected)
      tab.classList.toggle("text-blue-600", isSelected)
      tab.classList.toggle("border-transparent", !isSelected)
      tab.classList.toggle("text-gray-500", !isSelected)
      tab.classList.toggle("hover:text-gray-700", !isSelected)
      tab.classList.toggle("hover:border-gray-300", !isSelected)
    })
  }
} 