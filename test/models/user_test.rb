require "test_helper"

class UserTest < ActiveSupport::TestCase
  def setup
    @valid_attributes = {
      first_name: "Test",
      last_name: "User",
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    }
  end

  test "should be valid with all valid attributes and a valid llm_provider" do
    user = User.new(@valid_attributes.merge(llm_provider: "openai"))
    assert user.valid?, "User should be valid with openai provider: #{user.errors.full_messages.join(', ')}"
  end

  test "should be valid with llm_provider as anthropic" do
    user = User.new(@valid_attributes.merge(llm_provider: "anthropic"))
    assert user.valid?, "User should be valid with anthropic provider: #{user.errors.full_messages.join(', ')}"
  end

  test "should be valid with llm_provider as gemini" do
    user = User.new(@valid_attributes.merge(llm_provider: "gemini"))
    assert user.valid?, "User should be valid with gemini provider: #{user.errors.full_messages.join(', ')}"
  end

  test "should be invalid with an unsupported llm_provider" do
    user = User.new(@valid_attributes.merge(llm_provider: "unknown_provider"))
    assert_not user.valid?, "User should be invalid with an unknown_provider"
    assert_includes user.errors[:llm_provider], "unknown_provider is not a supported LLM provider. Supported providers are: openai, anthropic, gemini."
  end

  test "should be valid with a nil llm_provider" do
    user = User.new(@valid_attributes.merge(llm_provider: nil))
    assert user.valid?, "User should be valid with a nil llm_provider: #{user.errors.full_messages.join(', ')}"
  end

  test "after_create callback enqueues CreateDefaultCategoriesJob" do
    user = User.new(@valid_attributes)
    assert_enqueued_with(job: CreateDefaultCategoriesJob) do
      user.save!
    end
  end

  test "does not enqueue CreateDefaultCategoriesJob if user creation fails" do
    user = User.new(@valid_attributes.except(:email)) # Invalid user
    assert_no_enqueued_jobs(only: CreateDefaultCategoriesJob) do
      user.save
    end
  end

  # --- Encryption Tests for llm_api_key ---
  test "llm_api_key is encrypted and decrypted transparently" do
    api_key_plaintext = "sk-thisisarealapikey12345"
    user = User.new(@valid_attributes.merge(llm_provider: "openai", llm_api_key: api_key_plaintext))
    assert user.save, "User should save successfully: #{user.errors.full_messages.join(', ')}"
    
    user.reload
    assert_equal api_key_plaintext, user.llm_api_key, "Retrieved llm_api_key should match the original plaintext key"
  end

  test "llm_api_key raw value in database is encrypted" do
    api_key_plaintext = "sk-anotherrealapikey67890"
    user = User.new(@valid_attributes.merge(llm_provider: "openai", llm_api_key: api_key_plaintext))
    assert user.save, "User should save successfully: #{user.errors.full_messages.join(', ')}"
    
    user.reload
    
    # Fetch the raw value stored in the database for the attribute
    # This requires the record to be persisted and reloaded.
    raw_encrypted_value = user.read_attribute_before_type_cast(:llm_api_key)
    
    assert_not_nil raw_encrypted_value, "Raw encrypted value should not be nil"
    assert_not_equal api_key_plaintext, raw_encrypted_value, "Raw value in DB should be different from plaintext"
    
    # Also check that the getter still returns the decrypted value
    assert_equal api_key_plaintext, user.llm_api_key, "Getter should still return decrypted value"
  end

  test "llm_api_key can be nil and remains nil after save and reload" do
    user = User.new(@valid_attributes.merge(llm_provider: "openai", llm_api_key: nil))
    assert user.save, "User should save successfully with nil llm_api_key: #{user.errors.full_messages.join(', ')}"
    
    user.reload
    assert_nil user.llm_api_key, "llm_api_key should be nil after reload"
    
    raw_value = user.read_attribute_before_type_cast(:llm_api_key)
    assert_nil raw_value, "Raw value for nil llm_api_key should also be nil"
  end

  test "updating llm_api_key works with encryption" do
    initial_key = "key-initial-123"
    updated_key = "key-updated-456"
    
    user = User.new(@valid_attributes.merge(llm_provider: "openai", llm_api_key: initial_key))
    assert user.save
    user.reload
    assert_equal initial_key, user.llm_api_key

    user.update(llm_api_key: updated_key)
    user.reload
    assert_equal updated_key, user.llm_api_key
    
    raw_updated_value = user.read_attribute_before_type_cast(:llm_api_key)
    assert_not_equal updated_key, raw_updated_value
    assert_not_nil raw_updated_value
  end
end
