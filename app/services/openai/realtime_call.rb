require "net/http"
require "openssl"
require "securerandom"
require "timeout"

module OpenAI
  class RealtimeCall
    ENDPOINT = URI("https://api.openai.com/v1/realtime/calls")
    DEFAULT_MODEL = "gpt-realtime-2.1-mini"

    Result = Data.define(:status, :body) do
      def success?
        status == 201
      end
    end

    class ConnectionError < StandardError; end

    def self.api_key
      ENV["OPENAI_API_KEY"].presence ||
        Rails.application.credentials.dig(:openai, :api_key)
    end

    def self.configured?
      api_key.present?
    end

    def self.call(...)
      new(...).call
    end

    def initialize(
      user:,
      conversation:,
      sdp:,
      locale:,
      api_key: self.class.api_key,
      transport: nil
    )
      @user = user
      @conversation = conversation
      @sdp = sdp
      @locale = locale.to_s
      @api_key = api_key.to_s
      @transport = transport
    end

    def call
      raise ConnectionError, "OpenAI Realtime is not configured" if @api_key.blank?

      response = (@transport || method(:perform_request)).call(build_request)
      Result.new(status: response.code.to_i, body: response.body.to_s)
    rescue Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout, Timeout::Error,
      SocketError, SystemCallError, EOFError, OpenSSL::SSL::SSLError => error
      raise ConnectionError, error.class.name
    end

    private

    def build_request
      boundary = "----listen2me-#{SecureRandom.hex(16)}"
      request = Net::HTTP::Post.new(ENDPOINT)
      request["Authorization"] = "Bearer #{@api_key}"
      request["OpenAI-Safety-Identifier"] = safety_identifier
      request["Content-Type"] = "multipart/form-data; boundary=#{boundary}"
      request.body = multipart_body(boundary)
      request
    end

    def multipart_body(boundary)
      [
        multipart_part(boundary, "sdp", @sdp, "application/sdp"),
        multipart_part(boundary, "session", session_config.to_json, "application/json"),
        "--#{boundary}--\r\n"
      ].join
    end

    def multipart_part(boundary, name, value, content_type)
      "--#{boundary}\r\n" \
        "Content-Disposition: form-data; name=\"#{name}\"\r\n" \
        "Content-Type: #{content_type}\r\n" \
        "\r\n" \
        "#{value}\r\n"
    end

    def session_config
      {
        type: "realtime",
        model: ENV.fetch("OPENAI_REALTIME_MODEL", DEFAULT_MODEL),
        reasoning: {
          effort: "low"
        },
        output_modalities: [ "text" ],
        instructions: session_instructions,
        audio: {
          input: {
            transcription: {
              model: "gpt-4o-mini-transcribe",
              language: language_code
            },
            turn_detection: {
              type: "semantic_vad",
              eagerness: vad_eagerness,
              create_response: false,
              interrupt_response: false
            }
          }
        }
      }
    end

    def session_instructions
      if language_code == "de"
        "Du unterstützt eine Person, die Text als Stimme verwendet. Höre dem Gespräch zu. Antworte nie automatisch. Wenn Antwortvorschläge angefordert werden, formuliere sie kurz und immer aus Sicht der Listen2Me nutzenden Person."
      else
        "You support a person who uses text as their voice. Listen to the conversation. Never answer automatically. When reply suggestions are requested, keep them short and always write from the Listen2Me user's perspective."
      end
    end

    def language_code
      @locale.start_with?("de") ? "de" : "en"
    end

    def vad_eagerness
      value = ENV.fetch("OPENAI_REALTIME_VAD_EAGERNESS", "auto")
      %w[low medium high auto].include?(value) ? value : "auto"
    end

    def safety_identifier
      OpenSSL::HMAC.hexdigest(
        "SHA256",
        Rails.application.secret_key_base,
        "listen2me-realtime-user:#{@user.id}"
      )
    end

    def perform_request(request)
      http = Net::HTTP.new(ENDPOINT.host, ENDPOINT.port)
      http.use_ssl = true
      http.open_timeout = 5
      http.read_timeout = 20
      http.write_timeout = 10
      http.request(request)
    end
  end
end
