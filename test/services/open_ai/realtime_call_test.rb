require "test_helper"

class OpenAI::RealtimeCallTest < ActiveSupport::TestCase
  FakeResponse = Data.define(:code, :body)

  test "builds a text-only realtime session without exposing identifying data" do
    user = users(:default_user)
    user.llm_api_key = "private-openai-key"
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
      transport: transport
    ).call

    assert result.success?
    assert_equal "sdp-answer", result.body
    assert_equal "Bearer private-openai-key", captured_request["Authorization"]
    assert_match(/\A[0-9a-f]{64}\z/, captured_request["OpenAI-Safety-Identifier"])
    assert_not_includes captured_request["OpenAI-Safety-Identifier"], user.email

    session = multipart_json_part(captured_request.body, "session")
    assert_equal "gpt-realtime-2.1-mini", session.fetch("model")
    assert_equal [ "text" ], session.fetch("output_modalities")
    assert_equal false, session.dig("audio", "input", "turn_detection", "create_response")
    assert_equal false, session.dig("audio", "input", "turn_detection", "interrupt_response")
    assert_equal "de", session.dig("audio", "input", "transcription", "language")
    assert_includes captured_request.body, "v=0\r\no=browser"
  end

  private

  def multipart_json_part(body, name)
    match = body.match(
      /name="#{Regexp.escape(name)}"\r\nContent-Type: application\/json\r\n\r\n(.+?)\r\n--/m
    )
    JSON.parse(match[1])
  end
end
