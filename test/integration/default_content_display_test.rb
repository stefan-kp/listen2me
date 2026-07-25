require "test_helper"

class DefaultContentDisplayTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:default_user)
    @category = categories(:one)
    @language = languages(:de)
    sign_in @user
  end

  test "sentences with equal usage are displayed in stable creation order" do
    sentences = 11.times.map do |index|
      @user.sentences.create!(
        content: "Sortierter Standardsatz #{index + 1}",
        usage_count: 0,
        category: @category,
        language: @language
      )
    end

    get speeches_path(locale: :de)

    assert_response :success
    assert_select ".l2m-phrase-card", count: 10 do |cards|
      assert_equal(
        sentences.first(10).map(&:content),
        cards.map { |card| card["data-communicator-text-param"] }
      )
    end

    get category_speech_path(id: @category.id, locale: :de)

    assert_response :success
    assert_select ".l2m-phrase-card", count: 11 do |cards|
      assert_equal(
        sentences.map(&:content),
        cards.map { |card| card["data-communicator-text-param"] }
      )
    end
  end

  test "seeded category names follow the interface language" do
    DefaultContentInstaller.call(user: @user)

    get speeches_path(locale: :de)

    assert_response :success
    assert_select ".l2m-category-tab", text: /Grundbedürfnisse/
    assert_select ".l2m-category-tab", text: /Getränke/
    assert_select ".l2m-category-tab", text: /Basic Needs/, count: 0

    get speeches_path(locale: :en)

    assert_response :success
    assert_select ".l2m-category-tab", text: /Basic Needs/
    assert_select ".l2m-category-tab", text: /Drinks/
  end
end
