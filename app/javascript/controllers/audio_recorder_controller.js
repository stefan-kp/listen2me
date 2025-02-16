import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["indicator", "recognizedText", "input"]
  static values = { 
    conversationId: String
  }
  
  connect() {
    console.log("Audio recorder connected")
    this.isRecording = false
    this.setupSpeechRecognition()
    
    // Bind all methods that will be used as event handlers
    this.handleKeyPress = this.handleKeyPress.bind(this)
    this.startRecording = this.startRecording.bind(this)
    this.forceStopRecording = this.forceStopRecording.bind(this)
    
    // Add event listeners with bound methods
    this.inputTarget.addEventListener('keypress', this.handleKeyPress)
    window.addEventListener('speech:pauseRecording', this.forceStopRecording)
    window.addEventListener('speech:resumeRecording', this.startRecording)

    // Check stored state and start if enabled (default is true)
    const shouldRecord = localStorage.getItem('speechRecognitionEnabled') !== 'false'
    if (shouldRecord) {
      setTimeout(() => {
        this.startRecording()
      }, 500)
    } else {
      // Update UI to show disabled state
      this.indicatorTarget.classList.remove('text-red-500')
      this.indicatorTarget.classList.add('text-gray-400')
    }
  }
  
  disconnect() {
    console.log("Audio recorder disconnecting")
    this.forceStopRecording()
    
    // Remove event listeners with the same bound methods
    this.inputTarget.removeEventListener('keypress', this.handleKeyPress)
    window.removeEventListener('speech:pauseRecording', this.forceStopRecording)
    window.removeEventListener('speech:resumeRecording', this.startRecording)
  }
  
  setupSpeechRecognition() {
    console.log("Setting up speech recognition")
    const SpeechRecognition = window.SpeechRecognition || 
                             window.webkitSpeechRecognition
    
    if (!SpeechRecognition) {
      console.warn("Speech Recognition not supported")
      this.indicatorTarget.classList.add('text-gray-400')
      return
    }

    this.recognition = new SpeechRecognition()
    this.recognition.continuous = true
    this.recognition.interimResults = true
    this.recognition.lang = document.documentElement.lang || 'de-DE'
    
    this.setupRecognitionHandlers()
  }

  toggleRecording() {
    console.log("Toggle recording, current state:", this.isRecording)
    if (this.isRecording) {
      this.forceStopRecording()
      localStorage.setItem('speechRecognitionEnabled', 'false')
    } else {
      this.startRecording()
      localStorage.setItem('speechRecognitionEnabled', 'true')
    }
  }
  
  startRecording() {
    if (!this.recognition) return
    console.log("Starting recording...")
    
    try {
      this.isRecording = true
      this.recognition.start()
      this.indicatorTarget.classList.add('text-red-500')
      this.indicatorTarget.classList.remove('text-gray-400')
    } catch (error) {
      console.error("Error starting recognition:", error)
    }
  }
  
  forceStopRecording() {
    console.log("Force stopping recording...")
    if (!this.recognition) return
    
    try {
      this.isRecording = false
      this.recognition.abort() // Use abort() instead of stop()
      this.indicatorTarget.classList.remove('text-red-500')
      this.indicatorTarget.classList.add('text-gray-400')
    } catch (error) {
      console.error("Error stopping recognition:", error)
    }
  }
  
  setupRecognitionHandlers() {
    this.recognition.onresult = (event) => {
      const last = event.results.length - 1
      const text = event.results[last][0].transcript
      
      // Update the input field instead of a separate text display
      this.inputTarget.value = text
      
      if (event.results[last].isFinal) {
        this.sendRecognizedText(text)
      }
    }

    this.recognition.onerror = (event) => {
      console.error("Speech recognition error:", event.error)
      if (event.error === 'network') {
        this.stopRecording()
        setTimeout(() => this.startRecording(), 1000)
      }
    }
  }
  
  async sendRecognizedText(text, role = 'assistant') {  // Default to 'assistant' since this is the assistant's input
    try {
      const response = await fetch(`/conversations/${this.conversationIdValue}/messages`, {
        method: 'POST',
        headers: {
          "X-CSRF-Token": document.querySelector("[name='csrf-token']").content,
          "Content-Type": "application/json",
          "Accept": "text/vnd.turbo-stream.html",
        },
        body: JSON.stringify({
          content: text,
          role: role
        })
      })
      
      if (!response.ok) throw new Error(`HTTP error! status: ${response.status}`)
      
      const responseText = await response.text()
      Turbo.renderStreamMessage(responseText)
      
      // Clear input after successful send
      this.inputTarget.value = ''
      
    } catch (error) {
      console.error("Error sending text:", error)
    }
  }

  handleKeyPress(event) {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault()
      const text = this.inputTarget.value.trim()
      if (text) {
        this.sendRecognizedText(text, 'assistant')  // Explicitly set role to 'user' for keyboard input
      }
    }
  }
} 