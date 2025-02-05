import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["indicator", "recognizedText"]
  static values = { 
    conversationId: String
  }
  
  connect() {
    console.log("Audio recorder connected")
    this.indicatorTarget.classList.remove('text-red-500')
    this.setupSpeechRecognition()
    this.startRecording()
    
    // Event-Listener für Sprachsteuerung
    window.addEventListener("speech:pauseRecording", () => this.stopRecording())
    window.addEventListener("speech:resumeRecording", () => this.startRecording())
  }
  
  disconnect() {
    this.stopRecording()
    // Event-Listener entfernen
    window.removeEventListener("speech:pauseRecording", () => this.stopRecording())
    window.removeEventListener("speech:resumeRecording", () => this.startRecording())
  }
  
  setupSpeechRecognition() {
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition
    this.recognition = new SpeechRecognition()
    this.recognition.continuous = true
    this.recognition.interimResults = true
    this.recognition.lang = 'de-DE'

    this.recognition.onresult = (event) => {
      const last = event.results.length - 1
      const text = event.results[last][0].transcript
      
      this.recognizedTextTarget.textContent = text
      
      // Wenn das Ergebnis final ist, senden wir es an den Server
      if (event.results[last].isFinal) {
        this.sendRecognizedText(text)
      }
    }

    this.recognition.onerror = (event) => {
      console.error("Speech recognition error:", event.error)
      if (event.error === 'no-speech') {
        // Bei "no-speech" einfach weitermachen und nicht als Fehler anzeigen
        return
      }
      this.recognizedTextTarget.innerHTML = '<em class="text-red-500">Fehler bei der Spracherkennung</em>'
    }

    this.recognition.onend = () => {
      // Wenn die Erkennung endet, automatisch neu starten
      if (!this.stopping) {
        this.startRecording()
      }
    }
  }
  
  startRecording() {
    try {
      this.stopping = false
      this.recognition.start()
      console.log("Recording started")
      this.indicatorTarget.classList.add('text-red-500')
    } catch (error) {
      if (error.name === 'InvalidStateError') {
        // Wenn die Erkennung bereits läuft, ignorieren
        return
      }
      console.error("Error starting recognition:", error)
    }
  }
  
  stopRecording() {
    if (this.recognition) {
      this.stopping = true
      this.recognition.stop()
      this.indicatorTarget.classList.remove('text-red-500')
      console.log("Recording stopped")
    }
  }
  
  async sendRecognizedText(text) {
    try {
      const response = await fetch(`/conversations/${this.conversationIdValue}/messages`, {
        method: 'POST',
        headers: {
          "X-CSRF-Token": document.querySelector("[name='csrf-token']").content,
          "Content-Type": "application/json",
          "Accept": "text/vnd.turbo-stream.html, application/json",
          "Turbo-Frame": "messages"
        },
        body: JSON.stringify({
          content: text,
          role: "assistant"
        })
      })
      
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
      
      const responseText = await response.text()
      Turbo.renderStreamMessage(responseText)
      
    } catch (error) {
      console.error("Error sending text:", error)
    }
  }
} 