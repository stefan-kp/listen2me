require "test_helper"

class OpenAI::RealtimeCallTest < ActiveSupport::TestCase
  FakeResponse = Data.define(:code, :body)

  test "builds a realtime session limited to input transcription without exposing identifying data" do
    user = users(:default_user)
    captured_request = nil
    transport = lambda do |request|
      captured_request = request
      FakeResponse.new(code: "201", body: "sdp-answer")
    end

    result = OpenAI::RealtimeCall.new(
      user: user,
      conversation: user.conversations.create!,
      sdp: "v=0\r\no=browser",
      locale: :de,
      api_key: "server-managed-openai-key",
      transport: transport
    ).call

    assert result.success?
    assert_equal "sdp-answer", result.body
    assert_equal "Bearer server-managed-openai-key", captured_request["Authorization"]
    assert_match(/\A[0-9a-f]{64}\z/, captured_request["OpenAI-Safety-Identifier"])
    assert_not_includes captured_request["OpenAI-Safety-Identifier"], user.email

    session = multipart_json_part(captured_request.body, "session")
    assert_equal "gpt-realtime-2.1-mini", session.fetch("model")
    assert_equal "low", session.dig("reasoning", "effort")
    assert_equal [ "text" ], session.fetch("output_modalities")
    assert_equal false, session.dig("audio", "input", "turn_detection", "create_response")
    assert_equal false, session.dig("audio", "input", "turn_detection", "interrupt_response")
    assert_equal "auto", session.dig("audio", "input", "turn_detection", "eagerness")
    assert_equal "de", session.dig("audio", "input", "transcription", "language")
    assert_equal ENV.fetch("OPENAI_TRANSCRIPTION_MODEL", "gpt-4o-mini-transcribe"),
      session.dig("audio", "input", "transcription", "model")
    assert_includes session.fetch("instructions"), "keine Antwort"
    assert_includes captured_request.body, "v=0\r\no=browser"
  end

  test "refuses a call without a server-managed key" do
    user = users(:default_user)

    error = assert_raises OpenAI::RealtimeCall::ConnectionError do
      OpenAI::RealtimeCall.new(
        user: user,
        conversation: user.conversations.create!,
        sdp: "v=0\r\no=browser",
        locale: :en,
        api_key: nil,
        transport: ->(*) { flunk "transport must not be called" }
      ).call
    end

    assert_equal "OpenAI Realtime is not configured", error.message
  end

  test "turns upstream write timeouts into a controlled connection error" do
    user = users(:default_user)

    error = assert_raises OpenAI::RealtimeCall::ConnectionError do
      OpenAI::RealtimeCall.new(
        user: user,
        conversation: user.conversations.create!,
        sdp: "v=0\r\no=browser",
        locale: :en,
        api_key: "server-managed-openai-key",
        transport: ->(*) { raise Net::WriteTimeout }
      ).call
    end

    assert_equal "Net::WriteTimeout", error.message
  end

  private

  def multipart_json_part(body, name)
    match = body.match(
      /name="#{Regexp.escape(name)}"\r\nContent-Type: application\/json\r\n\r\n(.+?)\r\n--/m
    )
    JSON.parse(match[1])
  end
end
