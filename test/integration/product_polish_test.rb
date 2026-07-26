require "test_helper"

class ProductPolishTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:default_user)
  end

  test "new users see suggested sentences until they have usage history" do
    @user.sentences.update_all(usage_count: 0)
    @user.sentences.create!(
      content: "Ein hilfreicher Startsatz",
      usage_count: 0,
      category: categories(:one),
      language: languages(:de)
    )
    sign_in @user

    get speeches_path(locale: :de)

    assert_response :success
    assert_select "h2#frequent-title", text: "Empfohlene Sätze"
    assert_select ".l2m-phrase-card", text: /Ein hilfreicher Startsatz/
    assert_select "h2#frequent-title", text: "Häufig verwendet", count: 0
  end

  test "one frequently used sentence does not hide the remaining starter sentences" do
    DefaultContentInstaller.call(user: @user)
    @user.sentences.update_all(usage_count: 0)
    starter_sentence = @user.sentences
                            .where(language: languages(:de))
                            .order(:id)
                            .first!
    used_sentence = @user.sentences.create!(
      content: "Mein häufigster Satz",
      usage_count: 3,
      category: categories(:one),
      language: languages(:de)
    )
    sign_in @user

    get speeches_path(locale: :de)

    assert_response :success
    assert_select "h2#frequent-title", text: "Schneller Zugriff"
    assert_select ".l2m-phrase-card", count: 10 do |cards|
      assert_equal used_sentence.content, cards.first["data-communicator-text-param"]
      assert cards.any? { |card| card["data-communicator-text-param"] == starter_sentence.content }
    end
  end

  test "conversation and registration no longer expose prototype labels" do
    sign_in @user
    get new_conversation_path(locale: :de)

    assert_response :success
    assert_not_includes response.body, "Gesprächs-Demo"
    assert_not_includes response.body, "Demo-Eingabefeld"
    assert_not_includes response.body, "Demo-Konto"
    assert_not_includes response.body, "Live-KI testen"

    sign_out @user
    get new_user_registration_path(locale: :de)

    assert_response :success
    assert_not_includes response.body, "Deine persönliche Demo"
  end

  test "conversation analysis is disabled until the user has messages" do
    sign_in @user

    get settings_path(locale: :de, settings_section: "system")

    assert_response :success
    assert_select "form button[disabled][aria-describedby='summary-unavailable']", count: 1
    assert_select "#summary-unavailable", text: /Sobald ein Gespräch Beiträge enthält/

    post generate_summary_settings_path(locale: :de)

    assert_redirected_to settings_path(locale: :de, settings_section: "system")
    follow_redirect!
    assert_select "[role='alert']", text: /zuerst ein Gespräch/
  end
end
