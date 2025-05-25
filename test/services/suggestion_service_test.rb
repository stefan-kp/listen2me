require "test_helper"
require "minitest/mock"

class SuggestionServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:one) 
    @conversation = conversations(:one)
    @conversation.user = @user # Ensure association for tests

    # Default LLM provider and API key for user for most tests
    @user.update!(
      llm_provider: "openai", 
      llm_model: "gpt-3.5-turbo",
      llm_api_key: "dummy_openai_key_from_user" # API key now on user
    )
  end

  # --- initialize tests ---
  test "initialize with a valid provider and API key from user sets api_key and LLM client" do
    service = SuggestionService.new(@conversation)
    assert_equal "dummy_openai_key_from_user", service.instance_variable_get(:@api_key)
    assert_instance_of Langchain::LLM::OpenAI, service.instance_variable_get(:@llm)
  end

  test "initialize with a different valid provider (anthropic) and API key from user" do
    @user.update!(llm_provider: "anthropic", llm_api_key: "dummy_anthropic_key_from_user")
    service = SuggestionService.new(@conversation)
    assert_equal "dummy_anthropic_key_from_user", service.instance_variable_get(:@api_key)
    assert_instance_of Langchain::LLM::Anthropic, service.instance_variable_get(:@llm)
  end
  
  test "initialize with a user having a blank API key logs warning" do
    @user.update!(llm_api_key: "") # Blank API key
    
    Rails.logger.expects(:warn).with("User #{@user.id} has a blank API key for provider #{@user.llm_provider}.")
    
    # Service initialization should still proceed
    service = SuggestionService.new(@conversation)
    assert_equal "", service.instance_variable_get(:@api_key) 
    assert_instance_of Langchain::LLM::OpenAI, service.instance_variable_get(:@llm) # LLM client still instantiated
  end

  test "create_llm_client raises error if user API key is blank" do
    @user.update!(llm_api_key: "") # Blank API key
    service = SuggestionService.new(@conversation) # Initialize will log a warning

    exception = assert_raises RuntimeError do
      service.send(:create_llm_client) # Attempt to create client
    end
    assert_match "User #{@user.id} has a blank API key for provider #{@user.llm_provider}. Cannot create LLM client.", exception.message
  end

  test "initialize with an LLM provider not in the case statement raises RuntimeError" do
    # This provider might be valid at model level, but not supported by service's case statement
    @user.update!(llm_provider: "another_valid_but_unhandled_provider", llm_api_key: "some_key") 

    exception = assert_raises RuntimeError do
      SuggestionService.new(@conversation)
    end
    assert_match "Unknown LLM provider: another_valid_but_unhandled_provider", exception.message
  end

  # --- parse_suggestions tests (These remain largely the same as they don't depend on API key source) ---
  test "parse_suggestions with valid JSON string returns the array of suggestions" do
    # Re-initialize service with a user that has an API key for this test,
    # as setup might be altered by other tests.
    @user.update!(llm_api_key: "dummy_key_for_parsing_test")
    service = SuggestionService.new(@conversation)
    json_string = '{"response": ["Suggestion one", "Suggestion two"]}'
    expected_array = ["Suggestion one", "Suggestion two"]
    assert_equal expected_array, service.send(:parse_suggestions, json_string)
  end

  test "parse_suggestions with malformed JSON string logs error and returns empty array" do
    @user.update!(llm_api_key: "dummy_key_for_parsing_test")
    service = SuggestionService.new(@conversation)
    malformed_json = '{"response": "bad json'
    
    Rails.logger.expects(:error).with(regexp_matches(/Failed to parse LLM response as JSON/))
    Rails.logger.expects(:error).with("Problematic string: #{malformed_json}")
    
    assert_equal [], service.send(:parse_suggestions, malformed_json)
  end

  test "parse_suggestions with valid JSON but incorrect structure logs error and returns empty array" do
    @user.update!(llm_api_key: "dummy_key_for_parsing_test")
    service = SuggestionService.new(@conversation)
    incorrect_structure_json = '{"other_key": ["one", "two"]}'
    
    Rails.logger.expects(:error).with("LLM response JSON does not have the expected structure. Missing 'response' key or it's not an array.")
    Rails.logger.expects(:error).with("Received JSON: #{incorrect_structure_json}")

    assert_equal [], service.send(:parse_suggestions, incorrect_structure_json)
  end
  
  test "parse_suggestions with JSON where response is not an array logs error and returns empty array" do
    @user.update!(llm_api_key: "dummy_key_for_parsing_test")
    service = SuggestionService.new(@conversation)
    json_response_not_array = '{"response": "This is a string, not an array"}'

    Rails.logger.expects(:error).with("LLM response JSON does not have the expected structure. Missing 'response' key or it's not an array.")
    Rails.logger.expects(:error).with("Received JSON: #{json_response_not_array}")

    assert_equal [], service.send(:parse_suggestions, json_response_not_array)
  end

  test "parse_suggestions with an empty string logs warning and returns empty array" do
    @user.update!(llm_api_key: "dummy_key_for_parsing_test")
    service = SuggestionService.new(@conversation)
    empty_string = ""
    
    Rails.logger.expects(:warn).with("LLM completion was blank. Cannot parse suggestions.")
    
    assert_equal [], service.send(:parse_suggestions, empty_string)
  end

  test "parse_suggestions with a nil input logs warning and returns empty array" do
    @user.update!(llm_api_key: "dummy_key_for_parsing_test")
    service = SuggestionService.new(@conversation)
    nil_input = nil
    
    Rails.logger.expects(:warn).with("LLM completion was blank. Cannot parse suggestions.")
    
    assert_equal [], service.send(:parse_suggestions, nil_input)
  end

  # --- generate_suggestions basic integration (mocking LLM call) ---
  test "generate_suggestions successfully calls LLM and parses response" do
    # Ensure user has API key for this test
    @user.update!(llm_api_key: "dummy_openai_key_from_user_generate")
    service = SuggestionService.new(@conversation)
    
    mock_llm_client = Minitest::Mock.new
    mock_llm_response = Minitest::Mock.new
    mock_llm_response.expect :completion, '{"response": ["Mocked suggestion 1", "Mocked suggestion 2"]}'
    mock_llm_client.expect :chat, mock_llm_response, [Hash, Hash]

    service.instance_variable_set(:@llm, mock_llm_client)

    expected_suggestions = ["Mocked suggestion 1", "Mocked suggestion 2"]
    actual_suggestions = service.generate_suggestions
    
    assert_equal expected_suggestions, actual_suggestions
    mock_llm_client.verify
    mock_llm_response.verify
  end

  test "generate_suggestions handles LLM client error gracefully" do
    @user.update!(llm_api_key: "dummy_openai_key_from_user_error")
    service = SuggestionService.new(@conversation)
    
    mock_llm_client = Minitest::Mock.new
    mock_llm_client.expect :chat, nil do |_args| 
      raise StandardError, "LLM API Error"
    end
    
    service.instance_variable_set(:@llm, mock_llm_client)

    Rails.logger.expects(:error).with("Error generating suggestions: LLM API Error")
    
    assert_equal [], service.generate_suggestions
    mock_llm_client.verify
  end
end
