require "digest"

module Voice
  class SpeechOutput
    SAMPLE_RATE = 24_000
    CACHE_CHUNK_BYTES = 16.kilobytes
    MAX_AUDIO_BYTES = 8.megabytes
    ALTERNATIVE_PROVIDERS = %w[cartesia elevenlabs].freeze
    MEMORY_CACHE = ActiveSupport::Cache::MemoryStore.new(size: 32.megabytes)

    Result = Data.define(:provider, :cached)

    def self.provider_status(user:)
      {
        "browser" => true,
        "openai" => Voice::OpenAiSpeech.configured?,
        "cartesia" => Voice::CartesiaSpeech.configured? && UsageBudget.enabled?("cartesia"),
        "elevenlabs" => Voice::ElevenLabsSpeech.configured? && UsageBudget.enabled?("elevenlabs")
      }
    end

    def initialize(user:, provider:, locale:, clients: nil, cache: MEMORY_CACHE)
      @user = user
      @provider = provider.to_s
      @language = locale.to_s.start_with?("de") ? "de" : "en"
      @clients = clients
      @cache = cache
    end

    def stream(text:, on_provider: nil)
      raise UnavailableError, "Browser speech was requested" if @provider == "browser"
      raise UnavailableError, "Unknown speech provider" unless User::SPEECH_PROVIDERS.include?(@provider)

      candidates.each do |provider|
        next if ALTERNATIVE_PROVIDERS.include?(provider) && !UsageBudget.enabled?(provider)

        client = client_for(provider)
        next unless client.configured?

        emitted = false
        begin
          cache_key = cache_key_for(client, text)
          if (cached_audio = @cache.read(cache_key)).present?
            on_provider&.call(provider)
            each_chunk(cached_audio) { |chunk| yield chunk }
            return Result.new(provider:, cached: true)
          end

          UsageBudget.consume!(provider:, characters: text.length) if ALTERNATIVE_PROVIDERS.include?(provider)

          audio = +"".b
          announced = false
          client.stream(text:, language: @language) do |chunk|
            unless announced
              on_provider&.call(provider)
              announced = true
            end
            emitted = true
            audio << chunk
            raise ProviderError.new(provider:, message: "Speech response was too large") if audio.bytesize > MAX_AUDIO_BYTES

            yield chunk
          end
          raise ProviderError.new(provider:, message: "Speech response was empty") if audio.empty?

          @cache.write(cache_key, audio, expires_in: 1.day)
          return Result.new(provider:, cached: false)
        rescue ProviderError => error
          log_failure(error)
          raise UnavailableError, "Speech stream was interrupted" if emitted
        end
      end

      raise UnavailableError, "No speech provider is available"
    end

    private

    def candidates
      return [ "openai" ] if @provider == "openai"

      [ @provider, "openai" ].uniq
    end

    def client_for(provider)
      return @clients.fetch(provider) if @clients

      case provider
      when "openai" then Voice::OpenAiSpeech.new
      when "cartesia" then Voice::CartesiaSpeech.new
      when "elevenlabs" then Voice::ElevenLabsSpeech.new(user: @user)
      else raise UnavailableError, "Unknown speech provider"
      end
    end

    def cache_key_for(client, text)
      identity = client.cache_identity(language: @language)
      digest = Digest::SHA256.hexdigest([ identity, @language, text ].join("\0"))
      "listen2me/speech/v1/#{digest}"
    end

    def each_chunk(audio)
      offset = 0
      while offset < audio.bytesize
        yield audio.byteslice(offset, CACHE_CHUNK_BYTES)
        offset += CACHE_CHUNK_BYTES
      end
    end

    def log_failure(error)
      details = [ "provider=#{error.provider}", ("status=#{error.status}" if error.status), ("request_id=#{error.request_id}" if error.request_id) ].compact
      Rails.logger.warn "Speech provider unavailable (#{details.join(', ')})"
    end
  end
end
