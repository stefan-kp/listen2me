import assert from "node:assert/strict"
import { readFile } from "node:fs/promises"
import test from "node:test"

async function loadController(relativePath) {
  const source = await readFile(new URL(`../../${relativePath}`, import.meta.url), "utf8")
  const standalone = source.replace(
    'import { Controller } from "@hotwired/stimulus"',
    "class Controller {}"
  )
  const url = `data:text/javascript;base64,${Buffer.from(standalone).toString("base64")}`
  return (await import(url)).default
}

const AudioRecorderController = await loadController("app/javascript/controllers/audio_recorder_controller.js")
const RealtimeController = await loadController("app/javascript/controllers/realtime_controller.js")

test("the browser microphone stays closed until speech finishes successfully", () => {
  let beginCalls = 0
  const controller = {
    pausedForSpeech: false,
    shouldListen: true,
    userPaused: false,
    pauseForSpeech: AudioRecorderController.prototype.pauseForSpeech,
    resumeAfterSpeech: AudioRecorderController.prototype.resumeAfterSpeech,
    finishSpeech: AudioRecorderController.prototype.finishSpeech,
    clearFinalTranscript() {},
    stopRecording() {},
    setStatus() {},
    setDetail() {},
    updateToggle() {},
    beginPartnerTurn() { beginCalls += 1 }
  }

  controller.pauseForSpeech()
  assert.equal(controller.shouldListen, false)

  controller.resumeAfterSpeech()
  assert.equal(beginCalls, 0, "a generic recorder resume must not open a partner turn")

  controller.finishSpeech()
  assert.equal(beginCalls, 1, "successful playback opens exactly one partner turn")
})

test("a final browser transcript closes the microphone before it is emitted", () => {
  const events = []
  const controller = {
    shouldListen: true,
    processingPartner: false,
    transcribingStatusValue: "transcribing",
    recognizedDetailValue: "recognized",
    completePartnerTurn: AudioRecorderController.prototype.completePartnerTurn,
    clearFinalTranscript() {},
    stopRecording() { events.push(["stopped", this.shouldListen]) },
    setStatus() {},
    setDetail() {},
    updateToggle() {},
    dispatch(name, payload) { events.push([name, this.shouldListen, payload.detail]) }
  }

  controller.completePartnerTurn("  Guten Morgen  ")

  assert.equal(controller.shouldListen, false)
  assert.deepEqual(events, [
    ["stopped", false],
    ["transcript", false, { text: "Guten Morgen", source: "browser" }]
  ])
})

test("Realtime opens only for the partner turn and closes at voice activity end", () => {
  const events = []
  const controller = {
    active: true,
    userPaused: false,
    awaitingPartner: false,
    transcribing: false,
    partialTranscript: "",
    microphoneTrack: { enabled: false },
    seenTranscriptItems: new Set(),
    updateMicrophone: RealtimeController.prototype.updateMicrophone,
    finishSpeech: RealtimeController.prototype.finishSpeech,
    receiveSpeechStopped: RealtimeController.prototype.receiveSpeechStopped,
    receiveTranscript: RealtimeController.prototype.receiveTranscript,
    dispatch(name, payload = {}) { events.push([name, payload.detail]) }
  }

  controller.finishSpeech()
  assert.equal(controller.microphoneTrack.enabled, true)

  controller.receiveSpeechStopped()
  assert.equal(controller.microphoneTrack.enabled, false)
  assert.equal(controller.transcribing, true)

  controller.receiveTranscript({ item_id: "turn-1", transcript: "Wie geht es dir?" })
  assert.equal(controller.awaitingPartner, false)
  assert.equal(controller.microphoneTrack.enabled, false)
  assert.deepEqual(events, [
    ["transcribing", undefined],
    ["transcript", { text: "Wie geht es dir?", source: "realtime" }]
  ])

  controller.receiveTranscript({ item_id: "turn-1", transcript: "Wie geht es dir?" })
  assert.equal(events.length, 2, "a completed Realtime item is emitted once")
})

test("an empty Realtime transcript reopens the same partner turn", () => {
  const events = []
  const controller = {
    active: true,
    awaitingPartner: true,
    transcribing: true,
    partialTranscript: "",
    microphoneTrack: { enabled: false },
    seenTranscriptItems: new Set(),
    updateMicrophone: RealtimeController.prototype.updateMicrophone,
    retryPartnerTurn: RealtimeController.prototype.retryPartnerTurn,
    receiveTranscript: RealtimeController.prototype.receiveTranscript,
    dispatch(name) { events.push(name) }
  }

  controller.receiveTranscript({ item_id: "turn-empty", transcript: "  " })

  assert.equal(controller.awaitingPartner, true)
  assert.equal(controller.transcribing, false)
  assert.equal(controller.microphoneTrack.enabled, true)
  assert.deepEqual(events, ["retry"])
})

test("manual partner input closes browser and Realtime capture", () => {
  const browserController = {
    shouldListen: true,
    processingPartner: true,
    transcribingStatusValue: "transcribing",
    recognizedDetailValue: "recognized",
    stopPartnerTurn: AudioRecorderController.prototype.stopPartnerTurn,
    clearFinalTranscript() { this.cleared = true },
    stopRecording() { this.stopped = true },
    setIndicator() {},
    setStatus() {},
    setDetail() {},
    updateToggle() {}
  }
  const realtimeController = {
    active: true,
    awaitingPartner: true,
    transcribing: false,
    partialTranscript: "begonnen",
    microphoneTrack: { enabled: true },
    stopPartnerTurn: RealtimeController.prototype.stopPartnerTurn,
    updateMicrophone: RealtimeController.prototype.updateMicrophone
  }

  browserController.stopPartnerTurn()
  realtimeController.stopPartnerTurn()

  assert.equal(browserController.shouldListen, false)
  assert.equal(browserController.processingPartner, false)
  assert.equal(browserController.cleared, true)
  assert.equal(browserController.stopped, true)
  assert.equal(realtimeController.awaitingPartner, false)
  assert.equal(realtimeController.microphoneTrack.enabled, false)
  assert.equal(realtimeController.partialTranscript, "")
})

test("browser recognition combines final segments across a short pause", () => {
  const originalWindow = globalThis.window
  const originalDocument = globalThis.document
  const timers = new Map()
  let nextTimer = 1

  class FakeRecognition {}

  globalThis.window = {
    SpeechRecognition: FakeRecognition,
    clearTimeout(id) { timers.delete(id) },
    setTimeout(callback) {
      const id = nextTimer
      nextTimer += 1
      timers.set(id, callback)
      return id
    }
  }
  globalThis.document = { documentElement: { lang: "de-DE" } }

  try {
    const completed = []
    const controller = {
      isConnected: true,
      shouldListen: true,
      userPaused: false,
      pausedForSpeech: false,
      microphoneUnavailable: false,
      state: "idle",
      finalTranscriptTimer: null,
      finalTranscriptParts: [],
      recognitionGeneration: 0,
      dispatchedFinals: new Set(),
      listeningPrefixValue: "Hört zu:",
      interruptedDetailValue: "unterbrochen",
      unavailableDetailValue: "nicht verfügbar",
      setupSpeechRecognition: AudioRecorderController.prototype.setupSpeechRecognition,
      scheduleFinalTranscript: AudioRecorderController.prototype.scheduleFinalTranscript,
      setUnavailable() {},
      setListening() {},
      setIndicator() {},
      setDetail() {},
      startRecording() {},
      completePartnerTurn(text) { completed.push(text) }
    }

    controller.setupSpeechRecognition()
    controller.recognition.onstart()
    controller.recognition.onresult({
      resultIndex: 0,
      results: [{ 0: { transcript: "Guten" }, isFinal: true }]
    })
    assert.deepEqual(completed, [], "the first segment does not close the turn immediately")

    controller.recognition.onresult({
      resultIndex: 1,
      results: [
        { 0: { transcript: "Guten" }, isFinal: true },
        { 0: { transcript: "Morgen" }, isFinal: true }
      ]
    })

    const finalize = timers.get(controller.finalTranscriptTimer)
    finalize()
    assert.deepEqual(completed, ["Guten Morgen"])
  } finally {
    globalThis.window = originalWindow
    globalThis.document = originalDocument
  }
})

test("a partner turn survives while Realtime is still connecting", () => {
  const controller = {
    active: false,
    connecting: true,
    userPaused: false,
    awaitingPartner: false,
    transcribing: false,
    partialTranscript: "",
    microphoneTrack: { enabled: false },
    updateMicrophone: RealtimeController.prototype.updateMicrophone,
    finishSpeech: RealtimeController.prototype.finishSpeech
  }

  controller.finishSpeech()
  assert.equal(controller.awaitingPartner, true)
  assert.equal(controller.microphoneTrack.enabled, false, "audio is not sent before the session is ready")

  controller.active = true
  controller.connecting = false
  controller.updateMicrophone()
  assert.equal(controller.microphoneTrack.enabled, true, "the pending partner turn opens when Realtime becomes ready")
})

test("a browser transcript closes a pending Realtime partner turn before connection readiness", () => {
  const controller = {
    active: false,
    connecting: true,
    awaitingPartner: true,
    transcribing: false,
    partialTranscript: "",
    microphoneTrack: { enabled: false },
    stopPartnerTurn: RealtimeController.prototype.stopPartnerTurn,
    updateMicrophone: RealtimeController.prototype.updateMicrophone
  }

  controller.stopPartnerTurn()
  controller.active = true
  controller.connecting = false
  controller.updateMicrophone()

  assert.equal(controller.awaitingPartner, false)
  assert.equal(controller.microphoneTrack.enabled, false, "Realtime must not reopen after the browser already captured the reply")
})
