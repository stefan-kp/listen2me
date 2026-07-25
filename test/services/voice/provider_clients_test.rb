require "test_helper"

class Voice::ProviderClientsTest < ActiveSupport::TestCase
  FakeResponse = Data.define(:code, :body, :headers) do
    def [](name)
      headers.fetch(name.to_s.downcase, nil)
    end

    def read_body
      Array(body).each { |chunk| yield chunk }
    end
  end

  test "OpenAI sends exact text to the server speech endpoint and streams pcm" do
    captured = nil
    response = FakeResponse.new(code: "200", body: [ "pcm", "-audio" ], headers: {})
    client = Voice::OpenAiSpeech.new(
      api_key: "server-openai-key",
      transport: ->(request) { captured = request; response }
    )
    audio = String.new

    client.stream(text: "Bitte ein Glas Wasser.", language: "de") { |chunk| audio << chunk }

    payload = JSON.parse(captured.body)
    assert_equal "Bearer server-openai-key", captured["Authorization"]
    assert_equal "gpt-4o-mini-tts", payload.fetch("model")
    assert_equal "Bitte ein Glas Wasser.", payload.fetch("input")
    assert_equal "marin", payload.fetch("voice")
    assert_equal "pcm", payload.fetch("response_format")
    assert_includes payload.fetch("instructions"), "nichts hinzu"
    assert_equal "pcm-audio", audio
  end

  test "Cartesia uses the current bearer auth version and raw German pcm" do
    captured = nil
    response = FakeResponse.new(code: "200", body: "cartesia-pcm", headers: {})
    client = Voice::CartesiaSpeech.new(
      api_key: "server-cartesia-key",
      voice_id: "german-voice-id",
      transport: ->(request) { captured = request; response }
    )
    audio = String.new

    client.stream(text: "Ja, bitte.", language: "de") { |chunk| audio << chunk }

    payload = JSON.parse(captured.body)
    assert_equal "Bearer server-cartesia-key", captured["Authorization"]
    assert_equal "2026-03-01", captured["Cartesia-Version"]
    assert_equal "sonic-3.5", payload.fetch("model_id")
    assert_equal "de", payload.fetch("language")
    assert_equal "german-voice-id", payload.dig("voice", "id")
    assert_equal "raw", payload.dig("output_format", "container")
    assert_equal "pcm_s16le", payload.dig("output_format", "encoding")
    assert_equal 24_000, payload.dig("output_format", "sample_rate")
    assert_equal "cartesia-pcm", audio
  end

  test "ElevenLabs uses the fast multilingual stream without exposing its key in the body" do
    captured = nil
    response = FakeResponse.new(code: "200", body: "eleven-pcm", headers: {})
    client = Voice::ElevenLabsSpeech.new(
      user: users(:default_user),
      api_key: "server-elevenlabs-key",
      transport: ->(request) { captured = request; response }
    )
    audio = String.new

    client.stream(text: "Guten Morgen.", language: "de") { |chunk| audio << chunk }

    payload = JSON.parse(captured.body)
    assert_equal "server-elevenlabs-key", captured["xi-api-key"]
    assert_equal "eleven_flash_v2_5", payload.fetch("model_id")
    assert_equal "de", payload.fetch("language_code")
    assert_not_includes captured.body, "server-elevenlabs-key"
    assert_equal "eleven-pcm", audio
  end

  test "provider errors retain only safe status and request id metadata" do
    response = FakeResponse.new(
      code: "429",
      body: "upstream body containing sensitive details",
      headers: { "x-request-id" => "req-safe-id" }
    )
    client = Voice::OpenAiSpeech.new(
      api_key: "must-never-appear",
      transport: ->(_request) { response }
    )

    error = assert_raises Voice::ProviderError do
      client.stream(text: "Privater Text", language: "de") { flunk "no audio expected" }
    end

    assert_equal 429, error.status
    assert_equal "req-safe-id", error.request_id
    assert_not_includes error.message, "must-never-appear"
    assert_not_includes error.message, "Privater Text"
  end
end
