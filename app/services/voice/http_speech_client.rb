require "net/http"
require "openssl"
require "timeout"

module Voice
  class HttpSpeechClient
    NETWORK_ERRORS = [
      Net::OpenTimeout,
      Net::ReadTimeout,
      Net::WriteTimeout,
      Timeout::Error,
      SocketError,
      SystemCallError,
      EOFError,
      OpenSSL::SSL::SSLError
    ].freeze

    def initialize(transport: nil)
      @transport = transport
    end

    private

    def stream_request(uri, request, provider:, &block)
      if @transport
        handle_response(@transport.call(request), provider:, &block)
      else
        Timeout.timeout(total_timeout) do
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = uri.scheme == "https"
          http.open_timeout = open_timeout
          http.read_timeout = read_timeout
          http.write_timeout = write_timeout if http.respond_to?(:write_timeout=)
          http.request(request) do |response|
            handle_response(response, provider:, &block)
          end
        end
      end
    rescue *NETWORK_ERRORS => error
      raise ProviderError.new(provider:, message: error.class.name)
    end

    def handle_response(response, provider:)
      status = response.code.to_i
      request_id = response["x-request-id"] || response["request-id"] || response["cartesia-request-id"]

      unless status.between?(200, 299)
        discard_response_body(response)
        raise ProviderError.new(provider:, status:, request_id:)
      end

      if response.respond_to?(:read_body)
        response.read_body { |chunk| yield chunk.to_s.b if chunk.present? }
      elsif response.body.present?
        yield response.body.to_s.b
      end
    end

    def discard_response_body(response)
      if response.respond_to?(:read_body)
        response.read_body { |_chunk| }
      else
        response.body
      end
    rescue IOError
      nil
    end

    def open_timeout
      3
    end

    def read_timeout
      8
    end

    def write_timeout
      3
    end

    def total_timeout
      15
    end
  end
end
