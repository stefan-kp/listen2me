require "test_helper"

class UserDataIsolationTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:default_user)
    @other_category = categories(:other_users_category)
    @other_sentence = sentences(:other_users_sentence)
    @other_conversation = conversations(:other_users_conversation)

    sign_in @user
  end

  test "speech JSON contains no API key" do
    post speak_speech_path(id: sentences(:one).id), as: :json

    assert_response :success
    response_body = response.parsed_body
    assert_not response_body.key?("api_key")
    assert_not_includes response.body, @user.elevenlabs_api_key
  end

  test "cannot view another user's category" do
    get category_speech_path(id: @other_category.id)

    assert_response :not_found
  end

  test "cannot speak or delete another user's sentence" do
    assert_no_changes -> { @other_sentence.reload.usage_count } do
      post speak_speech_path(id: @other_sentence.id), as: :json
    end
    assert_response :not_found

    sign_in @user
    assert_no_difference "Sentence.count" do
      delete speech_path(id: @other_sentence.id)
    end
    assert_response :not_found
    assert Sentence.exists?(@other_sentence.id)
  end

  test "cannot start a conversation from another user's sentence" do
    assert_no_difference "Conversation.count" do
      post conversations_path, params: { sentence_id: @other_sentence.id }
    end

    assert_response :not_found
  end

  test "cannot assign another user's category to a new sentence" do
    assert_no_difference [ "Sentence.count", "Conversation.count" ] do
      post conversations_path, params: {
        category_id: @other_category.id,
        content: "Darf nicht gespeichert werden"
      }
    end

    assert_response :not_found
  end

  test "cannot assign another user's category when creating a speech" do
    assert_no_difference [ "Sentence.count", "Conversation.count" ] do
      post speeches_path, params: {
        category_id: @other_category.id,
        content: "Darf ebenfalls nicht gespeichert werden"
      }
    end

    assert_response :not_found
  end

  test "cannot view or request suggestions for another user's conversation" do
    get conversation_path(id: @other_conversation.id)
    assert_response :not_found

    sign_in @user
    post suggestions_conversation_path(id: @other_conversation.id),
      headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :not_found
  end

  test "cannot add a message to another user's conversation" do
    assert_no_difference "Message.count" do
      post conversation_messages_path(conversation_id: @other_conversation.id), params: {
        content: "Unberechtigter Beitrag",
        role: "speaker"
      }
    end

    assert_response :not_found
  end

  test "cannot update or delete another user's category" do
    original_name = @other_category.name

    patch category_path(id: @other_category.id), params: {
      category: { name: "Manipuliert", icon_name: "home" }
    }
    assert_response :not_found
    assert_equal original_name, @other_category.reload.name

    sign_in @user
    assert_no_difference "Category.count" do
      delete category_path(id: @other_category.id)
    end
    assert_response :not_found
    assert Category.exists?(@other_category.id)
  end
end
