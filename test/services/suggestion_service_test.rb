require "test_helper"

class SuggestionServiceTest < ActiveSupport::TestCase
  class FakeClient
    attr_reader :calls

    def initialize(completion: nil, configured: true, error: nil)
      @completion = completion
      @configured = configured
      @error = error
      @calls = []
    end

    def configured?
      @configured
    end

    def chat(**arguments)
      @calls << arguments
      raise @error if @error

      @completion
    end
  end

  test "returns exactly three safe fallback suggestions without a conversation" do
    suggestions = SuggestionService.new(
      nil,
      client: FakeClient.new(configured: false)
    ).generate_suggestions

    assert_equal 3, suggestions.size
    assert suggestions.all? { |suggestion| suggestion.keys == [ "content" ] }
    assert suggestions.all? { |suggestion| suggestion.fetch("content").present? }
  end

  test "formats a conversation without an initial sentence" do
    user = users(:default_user)
    conversation = Conversation.create!(user: user)
    conversation.messages.create!(role: :partner, content: "Möchtest du etwas trinken?")
    service = SuggestionService.new(
      conversation,
      client: FakeClient.new(configured: false)
    )

    messages = service.send(:format_conversation_history)
    payload = JSON.parse(messages.last.fetch(:content))

    assert_nil payload["category"]
    assert_equal(
      { "role" => "partner", "content" => "Möchtest du etwas trinken?" },
      payload["last_message"]
    )
  end

  test "uses the selected server-side proxy profile and accepts strict json" do
    user = users(:default_user)
    user.update!(suggestion_model_profile: "cheap")
    conversation = Conversation.create!(user: user)
    conversation.messages.create!(role: :partner, content: "Möchtest du etwas trinken?")
    client = FakeClient.new(
      completion: {
        response: [
          { content: "Wasser, bitte." },
          { content: "Nein, danke." },
          { content: "Später vielleicht." }
        ]
      }.to_json
    )

    suggestions = SuggestionService.new(conversation, client: client).generate_suggestions

    assert_equal(
      [ "Wasser, bitte.", "Nein, danke.", "Später vielleicht." ],
      suggestions.map { |suggestion| suggestion.fetch("content") }
    )

    call = client.calls.fetch(0)
    assert_equal "cheap", call.fetch(:profile)
    assert_equal 180, call.fetch(:max_tokens)
    assert_equal({ type: "json_object" }, call.fetch(:response_format))
    assert_equal "system", call.fetch(:messages).first.fetch(:role)
  end

  test "falls back when strict suggestion json validation fails" do
    user = users(:default_user)
    conversation = Conversation.create!(user: user)
    fallback = SuggestionService::FALLBACK_SUGGESTIONS.fetch("de")
    invalid_completions = [
      [ { content: "A" }, { content: "B" }, { content: "C" } ].to_json,
      { response: [ { content: "A" }, { content: "B" } ] }.to_json,
      {
        response: [
          { content: "A", confidence: 1 },
          { content: "B" },
          { content: "C" }
        ]
      }.to_json,
      {
        response: [
          { content: "A" },
          { content: "A" },
          { content: "C" }
        ]
      }.to_json,
      {
        response: [
          { content: "A" * 161 },
          { content: "B" },
          { content: "C" }
        ]
      }.to_json
    ]

    invalid_completions.each do |completion|
      suggestions = SuggestionService.new(
        conversation,
        client: FakeClient.new(completion: completion)
      ).generate_suggestions

      assert_equal fallback, suggestions
    end
  end

  test "returns static fallbacks when the proxy is unavailable" do
    user = users(:default_user)
    conversation = Conversation.create!(user: user)
    failing_client = FakeClient.new(error: LiteLlm::Client::ConnectionError.new("timeout"))

    suggestions = SuggestionService.new(
      conversation,
      client: failing_client
    ).generate_suggestions

    assert_equal SuggestionService::FALLBACK_SUGGESTIONS.fetch("de"), suggestions
  end

  test "does not call an unconfigured proxy" do
    user = users(:default_user)
    conversation = Conversation.create!(user: user)
    client = FakeClient.new(configured: false)

    suggestions = SuggestionService.new(conversation, client: client).generate_suggestions

    assert_equal SuggestionService::FALLBACK_SUGGESTIONS.fetch("de"), suggestions
    assert_empty client.calls
  end

  test "localizes fallbacks from the active request locale" do
    user = users(:default_user)
    user.update!(preferred_locale: "de")
    conversation = Conversation.create!(user: user)

    suggestions = I18n.with_locale(:en) do
      SuggestionService.new(
        conversation,
        client: FakeClient.new(configured: false)
      ).generate_suggestions
    end

    assert_equal SuggestionService::FALLBACK_SUGGESTIONS.fetch("en"), suggestions
  end

  test "conversation summaries also use the server proxy with the cheap profile" do
    user = users(:default_user)
    conversation = Conversation.create!(user: user)
    conversation.messages.create!(role: :speaker, content: "Ich trinke gerne Tee.")
    client = FakeClient.new(completion: "Die Person trinkt gerne Tee.")

    result = SuggestionService.new(
      conversation,
      client: client
    ).generate_conversation_summary

    assert_equal "Die Person trinkt gerne Tee.", result
    assert_equal "cheap", client.calls.fetch(0).fetch(:profile)
    assert_equal "Die Person trinkt gerne Tee.", user.reload.conversation_summary
  end

  test "does not share mutable fallback hashes between calls" do
    service = SuggestionService.new(nil, client: FakeClient.new(configured: false))
    first_result = service.generate_suggestions
    first_result.first["content"] = "changed"

    second_result = service.generate_suggestions

    assert_not_equal "changed", second_result.first.fetch("content")
  end
end
