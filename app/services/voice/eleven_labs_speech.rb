require "json"
require "cgi"

module Voice
  class ElevenLabsSpeech < HttpSpeechClient
    API_ROOT = "https://api.elevenlabs.io"
    VOICES_ENDPOINT = URI("#{API_ROOT}/v2/voices?page_size=1")
    SAMPLE_RATE = 24_000
    DEFAULT_MODEL = "eleven_flash_v2_5"

    def self.api_key
      ENV["ELEVENLABS_API_KEY"].presence || Rails.application.credentials.dig(:elevenlabs, :api_key)
    end

    def self.configured?
      api_key.present?
    end

    def initialize(user:, api_key: self.class.api_key, voice_id: nil, transport: nil)
      super(transport:)
      @user = user
      @api_key = api_key.to_s
      @configured_voice_id = voice_id.to_s.presence
    end

    def configured?
      @api_key.present?
    end

    def provider_name
      "elevenlabs"
    end

    def cache_identity(language:)
      configured_voice = @configured_voice_id || @user.elevenlabs_voice_id.presence || ENV["ELEVENLABS_VOICE_ID"].presence
      [ provider_name, model, configured_voice || "auto-#{language}" ].join(":")
    end

    def stream(text:, language:)
      raise ProviderError.new(provider: provider_name) unless configured?

      uri = URI("#{API_ROOT}/v1/text-to-speech/#{CGI.escape(voice_id(language))}/stream")
      uri.query = URI.encode_www_form(output_format: "pcm_24000")
      request = Net::HTTP::Post.new(uri)
      request["xi-api-key"] = @api_key
      request["Content-Type"] = "application/json"
      request.body = {
        text:,
        model_id: model,
        language_code: language
      }.to_json

      stream_request(uri, request, provider: provider_name) { |chunk| yield chunk }
    end

    private

    def model
      ENV.fetch("ELEVENLABS_TTS_MODEL", DEFAULT_MODEL)
    end

    def voice_id(language)
      @voice_id ||= @configured_voice_id || @user.elevenlabs_voice_id.presence || ENV["ELEVENLABS_VOICE_ID"].presence ||
        Rails.cache.fetch("listen2me/elevenlabs-voice/#{language}", expires_in: 1.day) do
          discover_voice_id
        end
    end

    def discover_voice_id
      request = Net::HTTP::Get.new(VOICES_ENDPOINT)
      request["xi-api-key"] = @api_key
      body = +"".b
      stream_request(VOICES_ENDPOINT, request, provider: provider_name) { |chunk| body << chunk }
      JSON.parse(body).fetch("voices").first&.fetch("voice_id") || raise(ProviderError.new(provider: provider_name))
    rescue JSON::ParserError, KeyError
      raise ProviderError.new(provider: provider_name)
    end

    def total_timeout
      ENV.fetch("ELEVENLABS_TTS_TIMEOUT_SECONDS", "12").to_i.clamp(5, 20)
    end
  end
end
