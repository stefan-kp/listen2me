import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]
  static values = {
    voiceId: String,
    apiKey: String,
    mode: String  // 'submit' oder 'speak'
  }

  connect() {
    console.log("Speech controller connected")
  }
  
  async speak(event) {
    if (event) event.preventDefault()
    const text = this.inputTarget.value
    
    if (this.hasApiKey) {
      await this.speakWithElevenLabs(text)
    } else {
      await this.speakWithBrowser(text)
    }
  }

  async speakAndSubmit(event) {
    if (event) event.preventDefault()
    const form = event.target.closest('form')
    
    try {
      // Erst sprechen
      await this.speak(event)
      
      // Dann Formular absenden
      if (form) form.requestSubmit()
    } catch (error) {
      console.error("Error in speakAndSubmit:", error)
    }
  }

  get hasApiKey() {
    return this.apiKeyValue && this.apiKeyValue.length > 0 && this.voiceIdValue && this.voiceIdValue.length > 0
  }

  async speakWithElevenLabs(text) {
    try {
      const response = await fetch('https://api.elevenlabs.io/v1/text-to-speech/' + this.voiceIdValue, {
        method: 'POST',
        headers: {
          'Accept': 'audio/mpeg',
          'Content-Type': 'application/json',
          'xi-api-key': this.apiKeyValue
        },
        body: JSON.stringify({
          text: text,
          model_id: 'eleven_multilingual_v2',
          voice_settings: {
            stability: 0.5,
            similarity_boost: 0.5
          }
        })
      })

      const audioBlob = await response.blob()
      const audioUrl = URL.createObjectURL(audioBlob)
      const audio = new Audio(audioUrl)
      await audio.play()
    } catch (error) {
      console.error('ElevenLabs API error:', error)
      // Fallback to browser speech if ElevenLabs fails
      await this.speakWithBrowser(text)
    }
  }

  async speakWithBrowser(text) {
    if (!window.speechSynthesis) {
      console.error('Browser speech synthesis not supported')
      return
    }

    // Cancel any ongoing speech
    window.speechSynthesis.cancel()

    const utterance = new SpeechSynthesisUtterance(text)
    
    // Set language based on the current page locale
    utterance.lang = document.documentElement.lang || 'de-DE'
    
    // Get available voices and try to find a matching one
    const voices = window.speechSynthesis.getVoices()
    const voice = voices.find(v => v.lang.startsWith(utterance.lang) && !v.localService) || 
                 voices.find(v => v.lang.startsWith(utterance.lang)) ||
                 voices[0]
    
    if (voice) {
      utterance.voice = voice
    }

    return new Promise((resolve) => {
      utterance.onend = () => resolve()
      window.speechSynthesis.speak(utterance)
    })
  }
} 