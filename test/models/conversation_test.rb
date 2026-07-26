require "test_helper"

class ConversationTest < ActiveSupport::TestCase
  test "allows a conversation without an initial sentence" do
    conversation = Conversation.new(user: users(:default_user))

    assert conversation.valid?
    assert_nil conversation.initial_sentence
  end

  test "still requires a user" do
    conversation = Conversation.new

    assert_not conversation.valid?
    assert conversation.errors[:user].present?
  end
end
