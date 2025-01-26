import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  connect() {
    document.addEventListener('click', this.closeOnClickOutside.bind(this))
  }

  disconnect() {
    document.removeEventListener('click', this.closeOnClickOutside.bind(this))
  }

  toggle(event) {
    event.stopPropagation()
    this.menuTarget.classList.toggle("hidden")
    
    const button = this.element.querySelector("button")
    const isExpanded = !this.menuTarget.classList.contains("hidden")
    button.setAttribute("aria-expanded", isExpanded)
  }

  closeOnClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.menuTarget.classList.add('hidden')
      this.element.querySelector("button").setAttribute("aria-expanded", "false")
    }
  }
} 