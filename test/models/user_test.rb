require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "preferences only accept supported values" do
    user = users(:default_user)

    user.preferred_locale = "fr"
    user.preferred_speech_mode = "automatic"
    user.suggestion_model_profile = "provider/model-name"

    assert_not user.valid?
    assert user.errors.of_kind?(:preferred_locale, :inclusion)
    assert user.errors.of_kind?(:preferred_speech_mode, :inclusion)
    assert user.errors.of_kind?(:suggestion_model_profile, :inclusion)
  end

  test "onboarding is complete when a completion timestamp exists" do
    user = users(:default_user)

    assert user.onboarding_completed?
    user.onboarding_completed_at = nil
    assert_not user.onboarding_completed?
  end

  test "provider keys are encrypted at rest" do
    user = users(:default_user)
    user.update!(
      elevenlabs_api_key: "elevenlabs-plain-secret",
      llm_api_key: "llm-plain-secret"
    )

    raw_values = ApplicationRecord.connection.select_one(<<~SQL)
      SELECT elevenlabs_api_key, llm_api_key
      FROM users
      WHERE id = #{ApplicationRecord.connection.quote(user.id)}
    SQL

    assert_equal "elevenlabs-plain-secret", user.reload.elevenlabs_api_key
    assert_equal "llm-plain-secret", user.llm_api_key
    assert_not_equal "elevenlabs-plain-secret", raw_values.fetch("elevenlabs_api_key")
    assert_not_equal "llm-plain-secret", raw_values.fetch("llm_api_key")
    assert_includes User.encrypted_attributes, :elevenlabs_api_key
    assert_includes User.encrypted_attributes, :llm_api_key
  end
end
