require "test_helper"

class SettingsAndAuthenticationTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:default_user)
  end

  test "settings expose no provider credentials and use accessible sections" do
    @user.update!(
      llm_api_key: "hidden-llm-provider-key",
      elevenlabs_api_key: "hidden-voice-provider-key"
    )
    sign_in @user

    get settings_path(locale: :de)

    assert_response :success
    assert_select "h1#settings-title", count: 1
    assert_select "[role='tablist']", count: 1
    assert_select "label[for='user_suggestion_model_profile_fast']", count: 1
    assert_select "label[for='user_suggestion_model_profile_cheap']", count: 1
    assert_select "label[for='user_speech_provider_openai']", count: 1
    assert_select "label[for='user_speech_provider_browser']", count: 1
    assert_select "label[for='user_speech_provider_cartesia']", count: 1
    assert_select "label[for='user_speech_provider_elevenlabs']", count: 1
    assert_select "[data-loading-button-target='icon']", count: 1
    assert_select "[data-loading-button-target='label']", count: 1
    assert_select "input[name='user[llm_api_key]']", count: 0
    assert_select "select[name='user[llm_provider]']", count: 0
    assert_select "input[name='user[elevenlabs_api_key]']", count: 0
    assert_not_includes response.body, @user.llm_api_key.to_s
    assert_not_includes response.body, @user.elevenlabs_api_key.to_s
  end

  test "settings update only safe profile voice and suggestion preferences" do
    @user.update!(
      llm_api_key: "existing-llm-provider-key",
      elevenlabs_api_key: "existing-voice-provider-key"
    )
    sign_in @user
    original_llm_key = @user.llm_api_key
    original_voice_key = @user.elevenlabs_api_key

    patch settings_path(locale: :de), params: {
      user: {
        description: "Kurze Angaben für passende Vorschläge.",
        suggestion_model_profile: "cheap",
        speech_provider: "browser",
        llm_api_key: "must-not-be-accepted",
        llm_provider: "untrusted-provider",
        elevenlabs_api_key: "must-not-be-accepted"
      }
    }

    assert_redirected_to root_path(locale: :de)
    @user.reload
    assert_equal "Kurze Angaben für passende Vorschläge.", @user.description
    assert_equal "cheap", @user.suggestion_model_profile
    assert_equal "browser", @user.speech_provider
    assert_equal original_llm_key, @user.llm_api_key
    assert_equal original_voice_key, @user.elevenlabs_api_key
  end

  test "settings reject an unsupported proxy model profile" do
    sign_in @user

    patch settings_path(locale: :de), params: {
      user: { suggestion_model_profile: "provider/model-name" }
    }

    assert_response :unprocessable_entity
    assert_equal "fast", @user.reload.suggestion_model_profile
  end

  test "password recovery uses the localized accessible auth shell" do
    get new_user_password_path(locale: :de)

    assert_response :success
    assert_select ".l2m-auth-page[aria-labelledby='forgot-password-title']", count: 1
    assert_select "h1#forgot-password-title", count: 1
    assert_select "label[for='user_email']", count: 1
    assert_select "input#user_email.l2m-input[autocomplete='email']", count: 1
    assert_select "input[type='submit'].l2m-button", count: 1
    assert_not_includes response.body, "translation missing"
  end

  test "account editing separates profile fields from account deletion" do
    sign_in @user

    get edit_user_registration_path(locale: :de)

    assert_response :success
    assert_select "h1#account-title", count: 1
    assert_select "label[for='user_first_name']", count: 1
    assert_select "label[for='user_last_name']", count: 1
    assert_select "label[for='user_current_password']", count: 1
    assert_select "aside.l2m-danger-card", count: 1
    assert_not_includes response.body, "translation missing"
  end
end
