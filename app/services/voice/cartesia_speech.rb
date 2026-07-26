require "json"

module Voice
  class CartesiaSpeech < HttpSpeechClient
    ENDPOINT = URI("https://api.cartesia.ai/tts/bytes")
    VOICES_ENDPOINT = URI("https://api.cartesia.ai/voices")
    API_VERSION = "2026-03-01"
    SAMPLE_RATE = 24_000
    DEFAULT_MODEL = "sonic-3.5"

    def self.api_key
      ENV["CARTESIA_API_KEY"].presence || Rails.application.credentials.dig(:cartesia, :api_key)
    end

    def self.configured?
      api_key.present?
    end

    def initialize(api_key: self.class.api_key, voice_id: nil, transport: nil)
      super(transport:)
      @api_key = api_key.to_s
      @configured_voice_id = voice_id.to_s.presence
      @voice_ids = {}
    end

    def configured?
      @api_key.present?
    end

    def provider_name
      "cartesia"
    end

    def cache_identity(language:)
      configured_voice = @configured_voice_id || ENV["CARTESIA_VOICE_ID"].presence
      [ provider_name, model, configured_voice || "auto-#{language}" ].join(":")
    end

    def stream(text:, language:)
      raise ProviderError.new(provider: provider_name) unless configured?

      request = Net::HTTP::Post.new(ENDPOINT)
      add_headers(request)
      request["Content-Type"] = "application/json"
      request.body = {
        model_id: model,
        transcript: text,
        voice: { mode: "id", id: voice_id(language) },
        language:,
        output_format: {
          container: "raw",
          encoding: "pcm_s16le",
          sample_rate: SAMPLE_RATE
        }
      }.to_json

      stream_request(ENDPOINT, request, provider: provider_name) { |chunk| yield chunk }
    end

    private

    def model
      ENV.fetch("CARTESIA_TTS_MODEL", DEFAULT_MODEL)
    end

    def voice_id(language)
      configured_voice = @configured_voice_id || ENV["CARTESIA_VOICE_ID"].presence
      return configured_voice if configured_voice

      @voice_ids[language] ||= Rails.cache.fetch("listen2me/cartesia-voice/#{language}", expires_in: 1.day) do
        discover_voice_id(language)
      end
    end

    def discover_voice_id(language)
      uri = VOICES_ENDPOINT.dup
      uri.query = URI.encode_www_form(limit: 1, language:)
      request = Net::HTTP::Get.new(uri)
      add_headers(request)
      body = +"".b
      stream_request(uri, request, provider: provider_name) { |chunk| body << chunk }
      JSON.parse(body).fetch("data").first&.fetch("id") || raise(ProviderError.new(provider: provider_name))
    rescue JSON::ParserError, KeyError
      raise ProviderError.new(provider: provider_name)
    end

    def add_headers(request)
      request["Authorization"] = "Bearer #{@api_key}"
      request["Cartesia-Version"] = ENV.fetch("CARTESIA_API_VERSION", API_VERSION)
    end

    def total_timeout
      ENV.fetch("CARTESIA_TTS_TIMEOUT_SECONDS", "12").to_i.clamp(5, 20)
    end
  end
end
