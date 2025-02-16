import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["indicator", "recognizedText"]
  static values = { 
    conversationId: String
  }
  
  connect() {
    console.log("Audio recorder connected")
    this.indicatorTarget.classList.remove('text-red-500')
    
    // Prüfen ob Speech Recognition verfügbar ist
    if (this.isSpeechRecognitionAvailable()) {
      this.setupSpeechRecognition()
      this.startRecording()
    } else {
      this.handleUnsupportedBrowser()
    }
    
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
  
  isSpeechRecognitionAvailable() {
    return 'SpeechRecognition' in window || 
           'webkitSpeechRecognition' in window ||
           'mozSpeechRecognition' in window ||
           'msSpeechRecognition' in window
  }
  
  handleUnsupportedBrowser() {
    console.warn("Speech Recognition is not supported in this browser")
    this.recognizedTextTarget.innerHTML = `
      <em class="text-yellow-600">
        ${I18n.t('speech_recognition.errors.unsupported')}
      </em>
    `
    const recordButton = this.element.querySelector('[data-audio-recorder-target="recordButton"]')
    if (recordButton) {
      recordButton.disabled = true
      recordButton.classList.add('opacity-50', 'cursor-not-allowed')
    }
  }
  
  setupSpeechRecognition() {
    const SpeechRecognition = window.SpeechRecognition || 
                             window.webkitSpeechRecognition ||
                             window.mozSpeechRecognition ||
                             window.msSpeechRecognition
    
    try {
      this.recognition = new SpeechRecognition()
      this.recognition.continuous = true
      this.recognition.interimResults = true
      this.recognition.lang = 'de-DE'
      
      this.setupRecognitionHandlers()
    } catch (error) {
      console.error("Error setting up speech recognition:", error)
      this.handleUnsupportedBrowser()
    }
  }
  
  setupRecognitionHandlers() {
    this.recognition.onresult = (event) => {
      const last = event.results.length - 1
      const text = event.results[last][0].transcript
      
      this.recognizedTextTarget.textContent = text
      
      if (event.results[last].isFinal) {
        this.sendRecognizedText(text)
      }
    }

    this.recognition.onerror = (event) => {
      console.error("Speech recognition error:", event.error)
      
      let errorKey = ''
      
      switch(event.error) {
        case 'no-speech':
          return
        case 'network':
          errorKey = 'network'
          setTimeout(() => this.startRecording(), 1000)
          break
        case 'not-allowed':
        case 'permission-denied':
          errorKey = 'not_allowed'
          this.handleUnsupportedBrowser()
          break
        case 'audio-capture':
          errorKey = 'audio_capture'
          this.handleUnsupportedBrowser()
          break
        case 'aborted':
          if (this.stopping) return
          errorKey = 'aborted'
          break
        default:
          errorKey = 'default'
      }
      
      this.recognizedTextTarget.innerHTML = `
        <em class="text-red-500">${I18n.t(`speech_recognition.errors.${errorKey}`)}</em>
      `
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