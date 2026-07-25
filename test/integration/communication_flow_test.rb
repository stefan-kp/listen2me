require "test_helper"

class CommunicationFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:default_user)
    sign_in @user
  end

  test "speech workspace renders without exposing credentials or other users data" do
    get speeches_path(locale: :en)

    assert_response :success
    assert_select "h1", text: "What would you like to say?"
    assert_select "[data-controller~='speech-mode']"
    assert_select ".l2m-urgent-button", count: 4
    assert_not_includes response.body, @user.elevenlabs_api_key
    assert_not_includes response.body, sentences(:other_users_sentence).content

    body = Nokogiri::HTML(response.body).at_css("body")
    followup_rules = JSON.parse(body["data-communicator-followup-rules-value"])
    default_followups = JSON.parse(body["data-communicator-default-followups-value"])
    assert followup_rules.all? { |rule| rule.key?("terms") && rule.key?("suggestions") }
    assert_equal 3, default_followups.size
  end

  test "speaking custom text stores a sentence without creating a conversation" do
    assert_difference "Sentence.count", 1 do
      assert_no_difference "Conversation.count" do
        post speeches_path,
          params: {
            content: "A newly spoken sentence",
            category_id: categories(:one).id
          },
          as: :json
      end
    end

    assert_response :created
    sentence = @user.sentences.find(response.parsed_body.fetch("id"))
    assert_equal "A newly spoken sentence", sentence.content
    assert_equal categories(:one), sentence.category
  end

  test "opening conversation mode is read only until its session is created" do
    assert_no_difference "Conversation.count" do
      get new_conversation_path
    end

    assert_response :success
    assert_select "h1", text: "Zuhören. Vorschlagen. Du entscheidest."
    assert_select "[data-controller~='audio-recorder']"
    assert_not_includes response.body, @user.elevenlabs_api_key

    workspace = Nokogiri::HTML(response.body).at_css("[data-conversation-fallback-suggestions-value]")
    assert_equal 3, JSON.parse(workspace["data-conversation-fallback-suggestions-value"]).size
  end

  test "conversation can start without an initial sentence and returns suggestions" do
    assert_difference "@user.conversations.count", 1 do
      post conversations_path, params: { conversation: {} }, as: :json
    end

    assert_response :created
    conversation = @user.conversations.find(response.parsed_body.fetch("id"))
    assert_nil conversation.initial_sentence

    assert_difference "conversation.messages.count", 1 do
      post conversation_messages_path(conversation_id: conversation.id),
        params: { content: "Möchtest du etwas trinken?", role: "partner" },
        as: :json
    end

    assert_response :created
    assert_equal "partner", conversation.messages.last.role

    post suggestions_conversation_path(id: conversation.id), as: :json

    assert_response :success
    assert_equal 3, response.parsed_body.fetch("suggestions").size

    get conversation_path(id: conversation.id)
    assert_response :success
    assert_select ".l2m-message-partner", text: /Möchtest du etwas trinken/
  end

  test "generated suggestions are rendered without triggering speech automatically" do
    conversation = @user.conversations.create!
    conversation.messages.create!(content: "Möchtest du etwas trinken?", role: :partner)

    post suggestions_conversation_path(id: conversation.id),
      headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_includes response.body, "conversation#useSuggestion"
    assert_not_includes response.body, "speech#speakAndSubmit"
    assert_not_includes response.body, "speech:finished"
  end

  test "oversized communication text is rejected before storage" do
    oversized_text = "x" * 241
    conversation = @user.conversations.create!

    assert_no_difference [ "Sentence.count", "Message.count" ] do
      post speeches_path,
        params: { content: oversized_text, category_id: categories(:one).id },
        as: :json
      assert_response :unprocessable_entity

      post conversation_messages_path(conversation_id: conversation.id),
        params: { content: oversized_text, role: "speaker" },
        as: :json
      assert_response :unprocessable_entity
    end
  end

  test "message roles are limited to speaker and partner" do
    conversation = @user.conversations.create!

    assert_no_difference "Message.count" do
      post conversation_messages_path(conversation_id: conversation.id),
        params: { content: "Untrusted role", role: "assistant" },
        as: :json
    end

    assert_response :unprocessable_entity
  end
end
