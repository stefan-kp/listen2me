require "json"

module Voice
  class OpenAiSpeech < HttpSpeechClient
    ENDPOINT = URI("https://api.openai.com/v1/audio/speech")
    SAMPLE_RATE = 24_000
    DEFAULT_MODEL = "gpt-4o-mini-tts"
    DEFAULT_VOICE = "marin"

    def self.api_key
      ENV["OPENAI_API_KEY"].presence || Rails.application.credentials.dig(:openai, :api_key)
    end

    def self.configured?
      api_key.present?
    end

    def initialize(api_key: self.class.api_key, transport: nil)
      super(transport:)
      @api_key = api_key.to_s
    end

    def configured?
      @api_key.present?
    end

    def provider_name
      "openai"
    end

    def cache_identity(_language:)
      [ provider_name, model, voice_identifier ].join(":")
    end

    def stream(text:, language:)
      raise ProviderError.new(provider: provider_name) unless configured?

      request = Net::HTTP::Post.new(ENDPOINT)
      request["Authorization"] = "Bearer #{@api_key}"
      request["Content-Type"] = "application/json"
      request.body = {
        model:,
        input: text,
        voice: voice_payload,
        instructions: instructions(language),
        response_format: "pcm"
      }.to_json

      stream_request(ENDPOINT, request, provider: provider_name) { |chunk| yield chunk }
    end

    private

    def model
      ENV.fetch("OPENAI_TTS_MODEL", DEFAULT_MODEL)
    end

    def voice_identifier
      ENV["OPENAI_CUSTOM_VOICE_ID"].presence || ENV.fetch("OPENAI_TTS_VOICE", DEFAULT_VOICE)
    end

    def voice_payload
      custom_voice_id = ENV["OPENAI_CUSTOM_VOICE_ID"].presence
      custom_voice_id ? { id: custom_voice_id } : voice_identifier
    end

    def instructions(language)
      if language == "de"
        "Sprich den Text exakt wie geschrieben, klar, ruhig und natürlich auf Deutsch. Füge nichts hinzu."
      else
        "Speak the text exactly as written, clearly, calmly, and naturally. Do not add anything."
      end
    end

    def read_timeout
      ENV.fetch("OPENAI_TTS_FIRST_BYTE_TIMEOUT", "8").to_i.clamp(3, 15)
    end

    def total_timeout
      ENV.fetch("OPENAI_TTS_TOTAL_TIMEOUT", "20").to_i.clamp(8, 30)
    end
  end
end
