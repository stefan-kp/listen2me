require "test_helper"

class OnboardingFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:default_user)
    sign_in @user
  end

  test "incomplete users are guided to onboarding" do
    @user.update_column(:onboarding_completed_at, nil)

    get speeches_path(locale: :de)

    assert_redirected_to onboarding_path(locale: :de)
  end

  test "onboarding is a focused three step flow" do
    @user.update_column(:onboarding_completed_at, nil)

    get onboarding_path(locale: :de)

    assert_response :success
    assert_select "h1", text: /Hallo Test/
    assert_select "fieldset", count: 3
    assert_select ".l2m-primary-nav", count: 0
    assert_select ".l2m-bottom-nav", count: 0
    assert_not_includes response.body, @user.elevenlabs_api_key
  end

  test "finishing onboarding saves safe preferences and opens speech output" do
    @user.update_column(:onboarding_completed_at, nil)

    patch onboarding_path(locale: :de), params: {
      user: {
        preferred_locale: "en",
        preferred_speech_mode: "draft",
        description: "Short answers are easiest for me."
      }
    }

    assert_redirected_to speeches_path(locale: :en)
    @user.reload
    assert @user.onboarding_completed?
    assert_equal "en", @user.preferred_locale
    assert_equal "draft", @user.preferred_speech_mode
    assert_equal "Short answers are easiest for me.", @user.description
  end

  test "unsupported onboarding choices are rejected" do
    @user.update_column(:onboarding_completed_at, nil)

    patch onboarding_path(locale: :de), params: {
      user: {
        preferred_locale: "invalid",
        preferred_speech_mode: "automatic"
      }
    }

    assert_response :unprocessable_entity
    assert_not @user.reload.onboarding_completed?
  end

  test "skip keeps defaults and completes onboarding" do
    @user.update_column(:onboarding_completed_at, nil)

    patch onboarding_path(locale: :de), params: { skip: "1" }

    assert_redirected_to speeches_path(locale: :de)
    assert @user.reload.onboarding_completed?
  end
end
