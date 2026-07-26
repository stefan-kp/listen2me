require "test_helper"

class SentenceManagementTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:default_user)
    @category = categories(:one)
    @sentence = @user.sentences.create!(
      content: "Bitte öffne das Fenster",
      category: @category,
      language: languages(:de),
      usage_count: 2
    )

    sign_in @user
  end

  test "sentence cards expose separate accessible speak and delete controls" do
    get speeches_path(locale: :de)

    assert_response :success
    assert_select "#sentence_#{@sentence.id}[role='listitem']" do
      assert_select "> button.l2m-phrase-card[aria-label=?]", "Satz vorlesen: #{@sentence.content}", count: 1
      assert_select "> form.l2m-phrase-delete-form[data-turbo-confirm]", count: 1 do
        assert_select "button.l2m-phrase-delete-button[aria-label=?]", "Satz löschen: #{@sentence.content}", count: 1
      end
      assert_select "button button", count: 0
    end
  end

  test "sentence deletion is labelled and confirmed in English" do
    english_sentence = sentences(:one)

    get speeches_path(locale: :en)

    assert_response :success
    assert_select "#sentence_#{english_sentence.id}[role='listitem']" do
      assert_select "> form.l2m-phrase-delete-form[data-turbo-confirm=?]",
        "Do you really want to delete the sentence “#{english_sentence.content}”? This cannot be undone.",
        count: 1
      assert_select "button[aria-label=?]", "Delete sentence: #{english_sentence.content}", count: 1
    end
  end

  test "deleting from all sentences returns to all sentences" do
    assert_difference("@user.sentences.count", -1) do
      delete speech_path(id: @sentence.id, locale: :de), params: { return_to: "speeches" }
    end

    assert_redirected_to speeches_path(locale: :de)
    follow_redirect!
    assert_select "[role='alert']", text: /Satz wurde gelöscht/
  end

  test "deleting from a category returns to that category" do
    assert_difference("@user.sentences.count", -1) do
      delete speech_path(id: @sentence.id, locale: :de), params: { return_to: "category" }
    end

    assert_redirected_to category_speech_path(id: @category.id, locale: :de)
    follow_redirect!
    assert_response :success
    assert_select "#sentence_#{@sentence.id}", count: 0
  end

  test "a user cannot delete another user's sentence" do
    other_sentence = sentences(:other_users_sentence)

    assert_no_difference("Sentence.count") do
      delete speech_path(id: other_sentence.id, locale: :de)
    end

    assert_response :not_found
  end
end
