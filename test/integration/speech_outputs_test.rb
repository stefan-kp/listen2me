require "test_helper"

class SpeechOutputsTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:default_user)
  end

  test "requires an authenticated user" do
    post speech_output_path(locale: :de), params: { text: "Hallo" }, as: :json

    assert_response :unauthorized
  end

  test "streams server audio with private no-store headers" do
    sign_in @user
    service = Object.new
    service.define_singleton_method(:stream) do |text:, on_provider: nil, &block|
      raise "unexpected text" unless text == "Bitte Wasser."
      on_provider&.call("openai")
      block.call("\x00\x01".b)
      block.call("\x02\x03".b)
    end

    with_speech_output_service(service) do
      post speech_output_path(locale: :de),
        params: { text: "Bitte Wasser.", provider: "openai" },
        as: :json
    end

    assert_response :success
    assert_equal "application/vnd.listen2me.pcm-stream", response.media_type
    assert_equal "24000", response.headers["X-Listen2Me-Sample-Rate"]
    assert_equal "openai", response.headers["X-Listen2Me-Provider"]
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_equal [ 2 ].pack("L<") + "\x00\x01".b + [ 2 ].pack("L<") + "\x02\x03".b + [ 0 ].pack("L<"), response.body.b
    assert_not_includes response.body, "server-openai-key"
  end

  test "rejects missing oversized or unknown speech requests before a provider call" do
    sign_in @user

    post speech_output_path(locale: :de), params: { text: "" }, as: :json
    assert_response :unprocessable_entity

    post speech_output_path(locale: :de), params: { text: "x" * 241 }, as: :json
    assert_response :unprocessable_entity

    post speech_output_path(locale: :de), params: { text: "Hallo", provider: "unknown" }, as: :json
    assert_response :unprocessable_entity
  end

  test "an interrupted provider stream never receives a success frame" do
    sign_in @user
    service = Object.new
    service.define_singleton_method(:stream) do |text:, on_provider: nil, &block|
      on_provider&.call("openai")
      block.call("partial".b)
      raise Voice::UnavailableError, "interrupted"
    end

    with_speech_output_service(service) do
      post speech_output_path(locale: :de), params: { text: "Nicht vollständig" }, as: :json
    end

    assert_equal [ 7 ].pack("L<") + "partial".b, response.body.b
    assert_not response.body.b.end_with?(SpeechOutputsController::END_FRAME)
  end

  test "browser speech selection spends no provider request" do
    sign_in @user
    @user.update!(speech_provider: "browser")

    post speech_output_path(locale: :de), params: { text: "Hallo" }, as: :json

    assert_response :no_content
  end

  test "spoken text is filtered from Rails parameter logs" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    assert_equal "[FILTERED]", filter.filter(text: "Ein privater Satz").fetch(:text)
  end

  private

  def with_speech_output_service(service)
    singleton = Voice::SpeechOutput.singleton_class
    original = singleton.instance_method(:new)
    singleton.define_method(:new) { |**_arguments| service }
    yield
  ensure
    singleton.define_method(:new, original)
  end
end
