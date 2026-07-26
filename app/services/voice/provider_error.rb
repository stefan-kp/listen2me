module Voice
  class ProviderError < StandardError
    attr_reader :provider, :status, :request_id

    def initialize(provider:, status: nil, request_id: nil, message: nil)
      @provider = provider.to_s
      @status = status
      @request_id = request_id.to_s.presence
      super(message || "#{@provider} speech request failed")
    end
  end
end
