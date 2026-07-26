require "json"
require "net/http"
require "openssl"
require "timeout"
require "uri"

module LiteLlm
  class Client
    UNSET = Object.new.freeze
    DEFAULT_FAST_MODEL = "fast"
    DEFAULT_CHEAP_MODEL = "cheap"
    DEFAULT_TIMEOUT_SECONDS = 5
    MIN_TIMEOUT_SECONDS = 3
    MAX_TIMEOUT_SECONDS = 5
    MODEL_PROFILES = %w[fast cheap].freeze

    class Error < StandardError; end
    class ConfigurationError < Error; end
    class ConnectionError < Error; end
    class ResponseError < Error; end

    def self.configured?
      new.configured?
    end

    def initialize(
      host: UNSET,
      secret: UNSET,
      fast_model: UNSET,
      cheap_model: UNSET,
      timeout_seconds: UNSET,
      transport: nil
    )
      @host = resolve_config(host, "LITELLM_HOST", :host).to_s.strip
      @secret = resolve_config(secret, "LITELLM_SECRET", :secret).to_s
      @models = {
        "fast" => resolve_model(fast_model, "LITELLM_FAST_MODEL", :fast_model, DEFAULT_FAST_MODEL),
        "cheap" => resolve_model(cheap_model, "LITELLM_CHEAP_MODEL", :cheap_model, DEFAULT_CHEAP_MODEL)
      }
      configured_timeout = timeout_seconds.equal?(UNSET) ? ENV["LITELLM_TIMEOUT_SECONDS"] : timeout_seconds
      @timeout_seconds = normalize_timeout(configured_timeout)
      @transport = transport
    end

    def configured?
      @secret.present? && endpoint.present?
    rescue URI::InvalidURIError
      false
    end

    def chat(messages:, profile: "fast", temperature: 0.4, max_tokens: 180, response_format: nil)
      raise ConfigurationError, "LiteLLM proxy is not configured" unless configured?

      payload = {
        model: model_for(profile),
        messages: messages,
        temperature: temperature,
        max_tokens: max_tokens
      }
      payload[:response_format] = response_format if response_format.present?

      response = (@transport || method(:perform_request)).call(build_request(payload))
      status = response.respond_to?(:code) ? response.code.to_i : 0
      raise ResponseError, "LiteLLM returned HTTP #{status}" unless status.between?(200, 299)

      body = response.respond_to?(:body) ? JSON.parse(response.body.to_s) : nil
      choice = body["choices"]&.first if body.is_a?(Hash) && body["choices"].is_a?(Array)
      completion = choice.dig("message", "content") if choice.is_a?(Hash)
      raise ResponseError, "LiteLLM response did not include a completion" if completion.blank?

      completion
    rescue JSON::ParserError => error
      raise ResponseError, error.class.name
    rescue Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout, Timeout::Error,
      SocketError, SystemCallError, EOFError, OpenSSL::SSL::SSLError => error
      raise ConnectionError, error.class.name
    end

    def model_for(profile)
      @models.fetch(profile.to_s) do
        raise ConfigurationError, "Unsupported LiteLLM model profile"
      end
    end

    private

    def configured_value(env_name, credential_name)
      ENV[env_name].presence || Rails.application.credentials.dig(:litellm, credential_name)
    end

    def resolve_config(explicit_value, env_name, credential_name)
      return explicit_value unless explicit_value.equal?(UNSET)

      configured_value(env_name, credential_name)
    end

    def resolve_model(explicit_value, env_name, credential_name, default)
      value = resolve_config(explicit_value, env_name, credential_name)
      value.to_s.presence || default
    end

    def normalize_timeout(value)
      parsed = Integer(value, exception: false)
      (parsed || DEFAULT_TIMEOUT_SECONDS).clamp(MIN_TIMEOUT_SECONDS, MAX_TIMEOUT_SECONDS)
    end

    def timeout_seconds
      @timeout_seconds
    end

    def endpoint
      return if @host.blank?

      uri = URI.parse(@host)
      return unless %w[http https].include?(uri.scheme) && uri.host.present?

      base_path = uri.path.to_s.sub(%r{/+\z}, "")
      base_path = "#{base_path}/v1" unless base_path.end_with?("/v1")
      uri.path = "#{base_path}/chat/completions"
      uri.query = nil
      uri.fragment = nil
      uri
    end

    def build_request(payload)
      request = Net::HTTP::Post.new(endpoint)
      request["Authorization"] = "Bearer #{@secret}"
      request["Content-Type"] = "application/json"
      request["Accept"] = "application/json"
      request.body = JSON.generate(payload)
      request
    end

    def perform_request(request)
      uri = endpoint
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = [ timeout_seconds, 2 ].min
      http.read_timeout = timeout_seconds
      http.write_timeout = [ timeout_seconds, 3 ].min
      http.max_retries = 0

      Timeout.timeout(timeout_seconds) do
        http.request(request)
      end
    end
  end
end
