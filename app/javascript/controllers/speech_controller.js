import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["text"]
  static values = {
    text: String,
    voiceId: String,
    apiKey: String
  }

  connect() {
    console.log("Speech controller connected")
  }
  
  async speak(event = null) {
    if (event) event.preventDefault()
    
    // Text entweder aus dem Value oder aus dem Target nehmen
    let text
    if (this.hasTextValue) {
      text = this.textValue
    } else if (this.hasTextTarget) {
      text = this.textTarget.value
    } else {
      console.error("No text source found")
      return
    }
    
    const trimmedText = text?.trim()
    
    if (!trimmedText || !this.voiceIdValue || !this.apiKeyValue) {
      console.error("Missing required values:", {
        text: trimmedText,
        voiceId: this.voiceIdValue,
        apiKey: this.apiKeyValue
      })
      return
    }
    
    // Spracherkennung pausieren
    this.dispatch("pauseRecording")
    
    console.log("Speaking text:", trimmedText)
    
    try {
      const audioResponse = await fetch(`https://api.elevenlabs.io/v1/text-to-speech/${this.voiceIdValue}/stream`, {
        method: 'POST',
        headers: {
          'Accept': 'audio/mpeg',
          'Content-Type': 'application/json',
          'xi-api-key': this.apiKeyValue
        },
        body: JSON.stringify({
          text: trimmedText,
          model_id: "eleven_multilingual_v2",
          voice_settings: {
            stability: 0.5,
            similarity_boost: 0.5
          }
        })
      })

      if (!audioResponse.ok) {
        throw new Error(`ElevenLabs API error: ${audioResponse.status}`)
      }

      const audioBlob = await audioResponse.blob()
      const audioUrl = URL.createObjectURL(audioBlob)
      const audio = new Audio(audioUrl)
      
      await audio.play()
      
      audio.onended = () => {
        URL.revokeObjectURL(audioUrl)
        // Event auslösen, dass Audio fertig ist
        this.dispatch('finished')
        // Spracherkennung wieder starten
        this.dispatch("resumeRecording")
      }
    } catch (error) {
      console.error("Fehler bei der Sprachausgabe:", error)
      // Bei Fehler auch die Spracherkennung wieder starten
      this.dispatch("resumeRecording")
    }
  }

  async speakAndSubmit(event) {
    if (event) event.preventDefault()
    
    // Erst sprechen
    await this.speak()
    
    // Dann Message erstellen
    const response = await fetch(`/conversations/${this.element.closest("[data-audio-recorder-conversation-id-value]").dataset.audioRecorderConversationIdValue}/messages`, {
      method: 'POST',
      headers: {
        "Content-Type": "application/json",
        "Accept": "text/vnd.turbo-stream.html, application/json",
        "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
      },
      body: JSON.stringify({
        content: this.textValue,
        role: "user"
      })
    })
    
    if (!response.ok) {
      console.error("Error creating message")
      return
    }
    
    const responseText = await response.text()
    Turbo.renderStreamMessage(responseText)
  }
} 