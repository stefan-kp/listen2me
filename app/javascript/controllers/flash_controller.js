import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["message"]

  connect() {
    // Initial versteckt
    this.messageTarget.classList.add('-translate-y-full', 'opacity-0')
    
    // Kurz warten und dann einblenden
    requestAnimationFrame(() => {
      this.messageTarget.classList.remove('-translate-y-full', 'opacity-0')
    })

    // Nach 5 Sekunden ausblenden
    setTimeout(() => {
      this.close()
    }, 5000)
  }

  close() {
    this.messageTarget.classList.add('-translate-y-full', 'opacity-0')
    
    // Nach der Animation entfernen
    setTimeout(() => {
      this.element.remove()
    }, 300)
  }
} 