require "test_helper"

class RealtimeCallsTest < ActionDispatch::IntegrationTest
  FakeResult = Data.define(:status, :body) do
    def success?
      status == 201
    end
  end

  setup do
    @user = users(:default_user)
    @conversation = @user.conversations.create!
    sign_in @user
  end

  test "realtime setup requires a server-managed OpenAI key" do
    with_realtime_configured(false) do
      post conversation_realtime_call_path(@conversation, locale: :de),
        params: valid_sdp,
        headers: { "CONTENT_TYPE" => "application/sdp" }
    end

    assert_response :unprocessable_entity
  end

  test "realtime setup is scoped to the current user" do
    with_realtime_configured(true) do
      post conversation_realtime_call_path(conversations(:other_users_conversation), locale: :de),
        params: valid_sdp,
        headers: { "CONTENT_TYPE" => "application/sdp" }
    end

    assert_response :not_found
  end

  test "realtime setup rejects malformed requests before calling OpenAI" do
    with_realtime_configured(true) do
      post conversation_realtime_call_path(@conversation, locale: :de),
        params: valid_sdp,
        headers: { "CONTENT_TYPE" => "text/plain" }
      assert_response :unsupported_media_type

      post conversation_realtime_call_path(@conversation, locale: :de),
        params: "x" * (RealtimeCallsController::MAX_SDP_BYTES + 1),
        headers: { "CONTENT_TYPE" => "application/sdp" }
      assert_response :unprocessable_entity
    end
  end

  test "realtime setup returns only the upstream SDP answer" do
    result = FakeResult.new(status: 201, body: "v=0\r\no=OpenAI answer")

    with_realtime_configured(true) do
      with_realtime_result(result) do
        post conversation_realtime_call_path(@conversation, locale: :de),
          params: valid_sdp,
          headers: { "CONTENT_TYPE" => "application/sdp" }
      end
    end

    assert_response :created
    assert_equal "application/sdp", response.media_type
    assert_equal result.body, response.body
    assert_not_includes response.body, "OPENAI_API_KEY"
  end

  private

  def valid_sdp
    "v=0\r\no=Listen2Me 1 1 IN IP4 127.0.0.1"
  end

  def with_realtime_result(result)
    singleton = OpenAI::RealtimeCall.singleton_class
    original = singleton.instance_method(:call)
    singleton.define_method(:call) { |**| result }
    yield
  ensure
    singleton.define_method(:call, original)
  end

  def with_realtime_configured(value)
    singleton = OpenAI::RealtimeCall.singleton_class
    original = singleton.instance_method(:configured?)
    singleton.define_method(:configured?) { value }
    yield
  ensure
    singleton.define_method(:configured?, original)
  end
end
