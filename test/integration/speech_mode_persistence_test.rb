require "test_helper"

class SpeechModePersistenceTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:default_user)
    sign_in @user
  end

  test "persists a supported speech mode for the signed in user" do
    patch speech_mode_path(locale: :de),
      params: { speech_mode: { mode: "draft" } },
      as: :json

    assert_response :no_content
    assert_equal "draft", @user.reload.preferred_speech_mode
  end

  test "rejects unsupported speech modes" do
    patch speech_mode_path(locale: :de),
      params: { speech_mode: { mode: "automatic" } },
      as: :json

    assert_response :unprocessable_entity
    assert_equal "direct", @user.reload.preferred_speech_mode
  end

  test "renders the stored preference as the initial header state" do
    @user.update!(preferred_speech_mode: "draft")

    get speeches_path(locale: :de)

    assert_response :success
    body = Nokogiri::HTML(response.body).at_css("body")
    assert_equal "draft", body["data-speech-mode-initial-mode-value"]
    assert_equal "listen2me:speech-mode:user-#{@user.id}",
      body["data-speech-mode-storage-key-value"]
    assert_select "button[data-mode='draft'].is-active[aria-pressed='true']", count: 1
    assert_select "button[data-mode='direct'].is-active", count: 0
  end
end
