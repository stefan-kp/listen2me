require "test_helper"

class MessageTest < ActiveSupport::TestCase
  test "uses separate content limits for speaker and partner turns" do
    conversation = users(:default_user).conversations.build

    assert_not Message.new(
      conversation: conversation,
      role: :speaker,
      content: "x" * (Message::SPEAKER_CONTENT_LIMIT + 1)
    ).valid?

    assert Message.new(
      conversation: conversation,
      role: :partner,
      content: "x" * (Message::SPEAKER_CONTENT_LIMIT + 1)
    ).valid?

    assert_not Message.new(
      conversation: conversation,
      role: :partner,
      content: "x" * (Message::PARTNER_CONTENT_LIMIT + 1)
    ).valid?
  end
end
