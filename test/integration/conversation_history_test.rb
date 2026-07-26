require "test_helper"

class ConversationHistoryTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:default_user)
    sign_in @user
  end

  test "history presents only the current users conversations in latest activity order" do
    older = @user.conversations.create!(created_at: 3.days.ago, updated_at: 3.days.ago)
    older.messages.create!(content: "Das ist das ältere Gespräch.", role: :speaker, created_at: 2.days.ago)

    recent = @user.conversations.create!(created_at: 2.days.ago, updated_at: 2.days.ago)
    recent.messages.create!(content: "Möchtest du heute Tee?", role: :partner, created_at: 1.hour.ago)
    recent.messages.create!(content: "Ja, sehr gerne.", role: :speaker, created_at: 30.minutes.ago)

    get conversations_path(locale: :de)

    assert_response :success
    assert_select ".l2m-history-page"
    assert_select ".l2m-history-card", count: 2
    assert_select ".l2m-history-card[aria-label*='Möchtest du heute Tee?']"
    assert_not_includes response.body, messages(:other_users_message).content
    assert_not_includes response.body, "bg-indigo"

    document = Nokogiri::HTML(response.body)
    card_hrefs = document.css(".l2m-history-card").map { |node| node["href"] }
    assert card_hrefs.first.end_with?("/conversations/#{recent.id}")
    assert card_hrefs.second.end_with?("/conversations/#{older.id}")
  end

  test "history has an accessible empty state and keeps a new conversation action" do
    @user.conversations.destroy_all

    get conversations_path(locale: :en)

    assert_response :success
    assert_select ".l2m-history-empty[aria-labelledby='conversation-history-empty-title']"
    assert_select ".l2m-history-empty h2", text: "No saved conversations yet"
    assert_select "a[href='#{new_conversation_path(locale: :en)}']", text: /Start your first conversation/
    assert_select ".l2m-history-card", count: 0
  end

  test "resuming renders immediately with fallbacks and requests contextual suggestions after connect" do
    conversation = @user.conversations.create!
    conversation.messages.create!(content: "Was möchtest du trinken?", role: :partner)

    get conversation_path(id: conversation.id, locale: :de)

    assert_response :success
    assert_select ".l2m-suggestion-button", count: 3
    assert_select ".l2m-suggestion-button", text: /Ja, bitte\./

    workspace = Nokogiri::HTML(response.body).at_css("[data-conversation-refresh-suggestions-on-connect-value]")
    assert_equal "true", workspace["data-conversation-refresh-suggestions-on-connect-value"]
    assert workspace["data-conversation-suggestions-url-template-value"].end_with?("/conversations/__ID__/suggestions")
  end

  test "an empty saved conversation does not request contextual suggestions" do
    conversation = @user.conversations.create!

    get conversation_path(id: conversation.id, locale: :de)

    assert_response :success
    workspace = Nokogiri::HTML(response.body).at_css("[data-conversation-refresh-suggestions-on-connect-value]")
    assert_equal "false", workspace["data-conversation-refresh-suggestions-on-connect-value"]
    assert_select ".l2m-conversation-topbar a[href='#{conversations_path(locale: :de)}']", text: /Zum Verlauf/
  end
end
