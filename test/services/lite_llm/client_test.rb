require "test_helper"

class LiteLlm::ClientTest < ActiveSupport::TestCase
  FakeResponse = Data.define(:code, :body)

  test "sends a server-authenticated chat completion to the normalized proxy endpoint" do
    captured_request = nil
    transport = lambda do |request|
      captured_request = request
      FakeResponse.new(
        code: "200",
        body: {
          choices: [ { message: { content: '{"response":[]}' } } ]
        }.to_json
      )
    end
    client = build_client(
      host: "https://llm.example.test/",
      fast_model: "proxy-fast",
      transport: transport
    )

    completion = client.chat(
      messages: [ { role: "user", content: "Hallo" } ],
      profile: "fast",
      response_format: { type: "json_object" }
    )

    assert_equal '{"response":[]}', completion
    assert_equal "/v1/chat/completions", captured_request.path
    assert_equal "Bearer proxy-secret", captured_request["Authorization"]
    assert_equal "application/json", captured_request["Content-Type"]

    payload = JSON.parse(captured_request.body)
    assert_equal "proxy-fast", payload.fetch("model")
    assert_equal 180, payload.fetch("max_tokens")
    assert_equal({ "type" => "json_object" }, payload.fetch("response_format"))
  end

  test "selects only an explicitly configured fast or cheap profile" do
    requests = []
    transport = lambda do |request|
      requests << JSON.parse(request.body)
      FakeResponse.new(
        code: "200",
        body: { choices: [ { message: { content: "ok" } } ] }.to_json
      )
    end
    client = build_client(
      fast_model: "proxy-fast",
      cheap_model: "proxy-cheap",
      transport: transport
    )

    client.chat(messages: [], profile: "cheap")

    assert_equal "proxy-cheap", requests.first.fetch("model")
    assert_raises(LiteLlm::Client::ConfigurationError) do
      client.chat(messages: [], profile: "provider/model-name")
    end
  end

  test "fails before transport when proxy configuration is missing" do
    client = LiteLlm::Client.new(
      host: nil,
      secret: nil,
      fast_model: "fast",
      cheap_model: "cheap",
      transport: ->(*) { flunk "transport must not be called" }
    )

    assert_not client.configured?
    assert_raises(LiteLlm::Client::ConfigurationError) do
      client.chat(messages: [])
    end
  end

  test "maps proxy and connection failures to bounded client errors" do
    http_error_client = build_client(
      transport: ->(*) { FakeResponse.new(code: "503", body: "unavailable") }
    )
    timeout_client = build_client(
      transport: ->(*) { raise Net::ReadTimeout }
    )

    assert_raises(LiteLlm::Client::ResponseError) do
      http_error_client.chat(messages: [])
    end
    assert_raises(LiteLlm::Client::ConnectionError) do
      timeout_client.chat(messages: [])
    end
  end

  test "rejects malformed successful responses" do
    invalid_json_client = build_client(
      transport: ->(*) { FakeResponse.new(code: "200", body: "not-json") }
    )
    missing_completion_client = build_client(
      transport: ->(*) { FakeResponse.new(code: "200", body: { choices: [] }.to_json) }
    )

    assert_raises(LiteLlm::Client::ResponseError) do
      invalid_json_client.chat(messages: [])
    end
    assert_raises(LiteLlm::Client::ResponseError) do
      missing_completion_client.chat(messages: [])
    end
  end

  test "clamps the total request timeout to three through five seconds" do
    assert_equal 3, build_client(timeout_seconds: 1).send(:timeout_seconds)
    assert_equal 4, build_client(timeout_seconds: 4).send(:timeout_seconds)
    assert_equal 5, build_client(timeout_seconds: 30).send(:timeout_seconds)
    assert_equal 5, build_client(timeout_seconds: "invalid").send(:timeout_seconds)
  end

  private

  def build_client(**overrides)
    LiteLlm::Client.new(
      **{
        host: "https://llm.example.test",
        secret: "proxy-secret",
        fast_model: "fast",
        cheap_model: "cheap",
        timeout_seconds: 5,
        transport: ->(*) {
          FakeResponse.new(
            code: "200",
            body: { choices: [ { message: { content: "ok" } } ] }.to_json
          )
        }
      }.merge(overrides)
    )
  end
end
