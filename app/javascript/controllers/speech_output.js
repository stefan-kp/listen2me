let activeGeneration = 0
let cancelActiveSpeech = null

export class SpeechCancelledError extends Error {
  constructor(reason) {
    super(`Speech ${reason}`)
    this.name = "SpeechCancelledError"
    this.reason = reason
  }
}

export function isSpeechCancellation(error) {
  return error instanceof SpeechCancelledError
}

export function speakText(text, options = {}) {
  const content = String(text || "").trim()

  if (!content) {
    return Promise.reject(new Error("No text to speak"))
  }

  if (!window.speechSynthesis || !window.SpeechSynthesisUtterance) {
    window.dispatchEvent(new CustomEvent("speech:unavailable"))
    return Promise.reject(new Error("Speech synthesis is not available"))
  }

  const previousCancellation = cancelActiveSpeech
  const generation = ++activeGeneration
  if (previousCancellation) previousCancellation("replaced", false)
  window.speechSynthesis.cancel()

  return new Promise((resolve, reject) => {
    let settled = false
    let recordingPaused = false
    let timeoutId = null
    const utterance = new SpeechSynthesisUtterance(content)
    utterance.lang = options.lang || document.documentElement.lang || "de-DE"
    utterance.rate = Number(options.rate || 1)

    const resumeRecording = () => {
      if (!recordingPaused) return

      recordingPaused = false
      window.dispatchEvent(new CustomEvent("speech:resumeRecording"))
    }

    const finish = (callback) => {
      if (settled) return

      settled = true
      window.clearTimeout(timeoutId)
      if (generation === activeGeneration) cancelActiveSpeech = null
      callback()
    }

    cancelActiveSpeech = (reason, shouldResume = true) => {
      finish(() => {
        if (shouldResume) resumeRecording()
        reject(new SpeechCancelledError(reason))
      })
    }

    const voices = window.speechSynthesis.getVoices()
    const language = utterance.lang.split("-")[0]
    const voice =
      voices.find((candidate) => candidate.lang === utterance.lang) ||
      voices.find((candidate) => candidate.lang.startsWith(language)) ||
      voices[0]

    if (voice) utterance.voice = voice

    utterance.onstart = () => {
      if (generation !== activeGeneration || settled) return

      recordingPaused = true
      window.dispatchEvent(new CustomEvent("speech:pauseRecording"))
      window.dispatchEvent(new CustomEvent("speech:started", { detail: { text: content } }))
    }

    utterance.onend = () => {
      if (generation !== activeGeneration || settled) return

      finish(() => {
        window.dispatchEvent(new CustomEvent("speech:finished", { detail: { text: content } }))
        resumeRecording()
        resolve(content)
      })
    }

    utterance.onerror = (event) => {
      if (generation !== activeGeneration || settled) return

      finish(() => {
        window.dispatchEvent(new CustomEvent("speech:failed", { detail: { text: content } }))
        resumeRecording()
        reject(new Error(event.error || "Speech synthesis failed"))
      })
    }

    timeoutId = window.setTimeout(() => {
      if (generation !== activeGeneration || settled) return

      window.speechSynthesis.cancel()
      finish(() => {
        resumeRecording()
        reject(new Error("Speech synthesis timed out"))
      })
    }, Math.max(15_000, content.length * 250))

    try {
      window.speechSynthesis.speak(utterance)
    } catch (error) {
      finish(() => {
        resumeRecording()
        reject(error)
      })
    }
  })
}

export function stopSpeaking() {
  const previousCancellation = cancelActiveSpeech
  activeGeneration += 1
  cancelActiveSpeech = null
  if (previousCancellation) previousCancellation("stopped")

  if (window.speechSynthesis) {
    window.speechSynthesis.cancel()
  }

  if (!previousCancellation) {
    window.dispatchEvent(new CustomEvent("speech:resumeRecording"))
  }
}
