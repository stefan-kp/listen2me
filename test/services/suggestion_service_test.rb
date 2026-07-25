require "test_helper"

class SuggestionServiceTest < ActiveSupport::TestCase
  test "returns exactly three safe fallback suggestions without a conversation" do
    suggestions = SuggestionService.new(nil).generate_suggestions

    assert_equal 3, suggestions.size
    assert suggestions.all? { |suggestion| suggestion.keys == [ "content" ] }
    assert suggestions.all? { |suggestion| suggestion.fetch("content").present? }
  end

  test "formats a conversation without an initial sentence" do
    user = users(:default_user)
    conversation = Conversation.create!(user: user)
    conversation.messages.create!(role: :partner, content: "Möchtest du etwas trinken?")
    service = SuggestionService.new(conversation)

    messages = service.send(:format_conversation_history)
    payload = JSON.parse(messages.last.fetch(:content))

    assert_nil payload["category"]
    assert_equal(
      { "role" => "partner", "content" => "Möchtest du etwas trinken?" },
      payload["last_message"]
    )
  end

  test "returns fallbacks when the llm call fails without making a real request" do
    user = users(:default_user)
    user.update_columns(llm_api_key: "test-key")
    conversation = Conversation.create!(user: user)
    failing_llm = Object.new
    failing_llm.define_singleton_method(:chat) { |**| raise "LLM unavailable" }
    service = SuggestionService.new(conversation)
    service.define_singleton_method(:llm) { failing_llm }

    suggestions = service.generate_suggestions

    assert_equal 3, suggestions.size
    assert_equal [ "content" ], suggestions.first.keys
  end

  test "does not share mutable fallback hashes between calls" do
    service = SuggestionService.new(nil)
    first_result = service.generate_suggestions
    first_result.first["content"] = "changed"

    second_result = service.generate_suggestions

    assert_not_equal "changed", second_result.first.fetch("content")
  end
end
