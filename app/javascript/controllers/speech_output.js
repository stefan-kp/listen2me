let activeGeneration = 0
let cancelActiveSpeech = null
let sharedAudioContext = null

const PCM_BLOCK_BYTES = 4_800
const PCM_FRAME_HEADER_BYTES = 4
const MAX_PCM_FRAME_BYTES = 8 * 1024 * 1024

export class SpeechCancelledError extends Error {
  constructor(reason) {
    super(`Speech ${reason}`)
    this.name = "SpeechCancelledError"
    this.reason = reason
  }
}

class RemoteSpeechError extends Error {
  constructor(message, playbackStarted = false) {
    super(message)
    this.name = "RemoteSpeechError"
    this.playbackStarted = playbackStarted
  }
}

export function isSpeechCancellation(error) {
  return error instanceof SpeechCancelledError
}

export function speakText(text, options = {}) {
  const content = String(text || "").trim()
  if (!content) return Promise.reject(new Error("No text to speak"))

  const previousCancellation = cancelActiveSpeech
  const generation = ++activeGeneration
  if (previousCancellation) previousCancellation("replaced", false)
  window.speechSynthesis?.cancel()

  return new Promise((resolve, reject) => {
    let settled = false
    let recordingPaused = false
    let speechStarted = false
    let cleanupCurrentOutput = () => {}
    let timeoutId = null

    const pauseRecording = () => {
      if (recordingPaused) return
      recordingPaused = true
      window.dispatchEvent(new CustomEvent("speech:pauseRecording"))
    }

    const resumeRecording = () => {
      if (!recordingPaused) return
      recordingPaused = false
      window.dispatchEvent(new CustomEvent("speech:resumeRecording"))
    }

    const markStarted = () => {
      if (speechStarted || settled || generation !== activeGeneration) return
      speechStarted = true
      window.dispatchEvent(new CustomEvent("speech:started", { detail: { text: content } }))
    }

    const registerCleanup = (cleanup) => {
      cleanupCurrentOutput = cleanup
    }

    const finish = (callback) => {
      if (settled) return
      settled = true
      window.clearTimeout(timeoutId)
      if (generation === activeGeneration) cancelActiveSpeech = null
      callback()
    }

    const succeed = (provider) => {
      finish(() => {
        window.dispatchEvent(new CustomEvent("speech:finished", { detail: { text: content, provider } }))
        resumeRecording()
        resolve({ text: content, provider })
      })
    }

    const fail = (error) => {
      finish(() => {
        cleanupCurrentOutput()
        window.dispatchEvent(new CustomEvent("speech:failed", { detail: { text: content } }))
        resumeRecording()
        reject(error)
      })
    }

    cancelActiveSpeech = (reason, shouldResume = true) => {
      finish(() => {
        cleanupCurrentOutput()
        if (shouldResume) resumeRecording()
        reject(new SpeechCancelledError(reason))
      })
    }

    timeoutId = window.setTimeout(() => {
      if (generation !== activeGeneration || settled) return
      fail(new Error("Speech synthesis timed out"))
    }, Math.max(20_000, content.length * 300))

    const run = async () => {
      pauseRecording()
      const remote = remoteSpeechConfig(options)

      if (remote) {
        try {
          const provider = await speakWithRemoteAudio(content, remote, { markStarted, registerCleanup })
          if (!settled && generation === activeGeneration) succeed(provider)
          return
        } catch (error) {
          if (settled || generation !== activeGeneration) return
          cleanupCurrentOutput()

          if (error.playbackStarted) {
            fail(error)
            return
          }

          window.dispatchEvent(new CustomEvent("speech:fallback", {
            detail: { provider: remote.provider }
          }))
        }
      }

      try {
        await speakWithBrowser(content, options, { markStarted, registerCleanup })
        if (!settled && generation === activeGeneration) succeed("browser")
      } catch (error) {
        if (!settled && generation === activeGeneration) fail(error)
      }
    }

    run()
  })
}

async function speakWithRemoteAudio(content, config, { markStarted, registerCleanup }) {
  const audioContext = audioContextForPlayback()
  if (!audioContext) throw new RemoteSpeechError("Web Audio is not available")

  const controller = new AbortController()
  const sources = new Set()
  let playbackStarted = false
  let nextStartTime = 0
  let lastSource = null

  registerCleanup(() => {
    controller.abort()
    sources.forEach((source) => {
      try {
        source.stop()
      } catch (_error) {
        // A source may already have ended.
      }
    })
    sources.clear()
  })

  try {
    await audioContext.resume()
    const response = await fetch(config.url, {
      method: "POST",
      headers: {
        "X-CSRF-Token": csrfToken(),
        "Content-Type": "application/json",
        "Accept": "application/vnd.listen2me.pcm-stream"
      },
      body: JSON.stringify({ text: content, provider: config.provider }),
      signal: controller.signal
    })

    if (!response.ok || !response.body) {
      throw new RemoteSpeechError(`Speech provider returned HTTP ${response.status}`)
    }

    const sampleRate = Number(response.headers.get("X-Listen2Me-Sample-Rate")) || 24_000
    const provider = response.headers.get("X-Listen2Me-Provider") || config.provider
    const reader = response.body.getReader()
    let protocolPending = new Uint8Array(0)
    let pcmPending = new Uint8Array(0)
    let streamComplete = false
    let lastPlaybackDone = null

    const schedule = (bytes) => {
      const evenLength = bytes.byteLength - (bytes.byteLength % 2)
      if (evenLength <= 0) return

      const frames = evenLength / 2
      const buffer = audioContext.createBuffer(1, frames, sampleRate)
      const samples = buffer.getChannelData(0)
      const view = new DataView(bytes.buffer, bytes.byteOffset, evenLength)
      for (let index = 0; index < frames; index += 1) {
        samples[index] = view.getInt16(index * 2, true) / 32_768
      }

      const source = audioContext.createBufferSource()
      source.buffer = buffer
      source.connect(audioContext.destination)
      const startAt = Math.max(nextStartTime, audioContext.currentTime + 0.04)
      nextStartTime = startAt + buffer.duration
      sources.add(source)
      lastPlaybackDone = new Promise((resolve) => {
        source.addEventListener("ended", () => {
          sources.delete(source)
          resolve()
        }, { once: true })
      })
      source.start(startAt)
      lastSource = source

      if (!playbackStarted) {
        playbackStarted = true
        markStarted()
      }
    }

    while (true) {
      const { value, done } = await reader.read()
      if (value?.byteLength) protocolPending = appendBytes(protocolPending, value)

      while (!streamComplete && protocolPending.byteLength >= PCM_FRAME_HEADER_BYTES) {
        const frameLength = new DataView(
          protocolPending.buffer,
          protocolPending.byteOffset,
          PCM_FRAME_HEADER_BYTES
        ).getUint32(0, true)
        if (frameLength > MAX_PCM_FRAME_BYTES) throw new RemoteSpeechError("Invalid speech frame", playbackStarted)
        if (frameLength === 0) {
          protocolPending = protocolPending.slice(PCM_FRAME_HEADER_BYTES)
          streamComplete = true
          break
        }
        if (protocolPending.byteLength < PCM_FRAME_HEADER_BYTES + frameLength) break

        const frame = protocolPending.slice(PCM_FRAME_HEADER_BYTES, PCM_FRAME_HEADER_BYTES + frameLength)
        protocolPending = protocolPending.slice(PCM_FRAME_HEADER_BYTES + frameLength)
        pcmPending = appendBytes(pcmPending, frame)

        while (pcmPending.byteLength >= PCM_BLOCK_BYTES) {
          schedule(pcmPending.slice(0, PCM_BLOCK_BYTES))
          pcmPending = pcmPending.slice(PCM_BLOCK_BYTES)
        }
      }

      if (done) break
    }

    if (!streamComplete || protocolPending.byteLength) {
      throw new RemoteSpeechError("Speech stream ended before completion", playbackStarted)
    }
    if (pcmPending.byteLength % 2 !== 0) {
      throw new RemoteSpeechError("Speech provider returned invalid PCM", playbackStarted)
    }
    if (pcmPending.byteLength) schedule(pcmPending)
    if (!playbackStarted || !lastSource || !lastPlaybackDone) {
      throw new RemoteSpeechError("Speech provider returned no audio")
    }

    await lastPlaybackDone
    return provider
  } catch (error) {
    if (error instanceof SpeechCancelledError) throw error
    throw new RemoteSpeechError(error.message || "Remote speech failed", playbackStarted)
  }
}

function speakWithBrowser(content, options, { markStarted, registerCleanup }) {
  if (!window.speechSynthesis || !window.SpeechSynthesisUtterance) {
    window.dispatchEvent(new CustomEvent("speech:unavailable"))
    return Promise.reject(new Error("Speech synthesis is not available"))
  }

  return new Promise((resolve, reject) => {
    const utterance = new SpeechSynthesisUtterance(content)
    utterance.lang = options.lang || document.documentElement.lang || "de-DE"
    utterance.rate = Number(options.rate || 1)

    const voices = window.speechSynthesis.getVoices()
    const language = utterance.lang.split("-")[0]
    const voice =
      voices.find((candidate) => candidate.lang === utterance.lang) ||
      voices.find((candidate) => candidate.lang.startsWith(language)) ||
      voices[0]
    if (voice) utterance.voice = voice

    registerCleanup(() => window.speechSynthesis.cancel())
    utterance.onstart = markStarted
    utterance.onend = () => resolve(content)
    utterance.onerror = (event) => reject(new Error(event.error || "Speech synthesis failed"))

    try {
      window.speechSynthesis.speak(utterance)
    } catch (error) {
      reject(error)
    }
  })
}

function remoteSpeechConfig(options) {
  const url = document.body?.dataset.speechOutputUrl
  const provider = options.provider || document.body?.dataset.speechProvider || "browser"
  if (!url || provider === "browser") return null

  return { url, provider }
}

function audioContextForPlayback() {
  const AudioContextClass = window.AudioContext || window.webkitAudioContext
  if (!AudioContextClass) return null
  sharedAudioContext ||= new AudioContextClass()
  return sharedAudioContext
}

function appendBytes(existing, incoming) {
  if (!existing.byteLength) return incoming

  const combined = new Uint8Array(existing.byteLength + incoming.byteLength)
  combined.set(existing)
  combined.set(incoming, existing.byteLength)
  return combined
}

function csrfToken() {
  return document.querySelector("meta[name='csrf-token']")?.content || ""
}

export function stopSpeaking() {
  const previousCancellation = cancelActiveSpeech
  activeGeneration += 1
  cancelActiveSpeech = null
  if (previousCancellation) previousCancellation("stopped")

  window.speechSynthesis?.cancel()
  if (!previousCancellation) window.dispatchEvent(new CustomEvent("speech:resumeRecording"))
}
