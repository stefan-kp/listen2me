require "test_helper"

class CategoriesManagementTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:default_user)
    sign_in @user
  end

  test "renders every curated icon with a localized label" do
    get new_category_path

    assert_response :success
    Category::ICONS.each do |icon_name|
      assert_select "label[for='category_icon_name_#{icon_name}']",
        text: I18n.t("category_management.icons.#{icon_name}")
    end
    assert_select "svg.l2m-category-choice-icon", count: Category::ICONS.size
  end

  test "shows an accessible error state for invalid input" do
    assert_no_difference -> { @user.categories.count } do
      post categories_path, params: {
        category: { name: "", icon_name: "not-a-real-icon" }
      }
    end

    assert_response :unprocessable_entity
    assert_select ".l2m-form-error[role='alert']"
    assert_select "input#category_name[aria-invalid='true']"
    assert_select "fieldset[aria-invalid='true']"
  end

  test "valid legacy icons render and remain usable while renaming" do
    category = categories(:test_category)

    %w[trash lock-closed].each do |legacy_icon_name|
      category.update_column(:icon_name, legacy_icon_name)

      get edit_category_path(id: category.id)
      assert_response :success
      assert_select "input#category_icon_name_#{legacy_icon_name}[checked='checked']"
      assert_select "label[for='category_icon_name_#{legacy_icon_name}']",
        text: "Bisheriges Symbol"

      patch category_path(id: category.id), params: {
        category: { name: "Umbenannt", icon_name: legacy_icon_name }
      }
      assert_redirected_to categories_path
      assert_equal legacy_icon_name, category.reload[:icon_name]
    end
  end

  test "unknown stored icons safely render in both active speech views and heal on edit" do
    category = categories(:test_category)
    category.update_column(:icon_name, "not-a-real-icon")

    get speeches_path
    assert_response :success

    get category_speech_path(id: category.id)
    assert_response :success

    get edit_category_path(id: category.id)
    assert_response :success
    assert_select "input#category_icon_name_star[checked='checked']"

    patch category_path(id: category.id), params: {
      category: { name: "Geheilt", icon_name: "star" }
    }
    assert_redirected_to categories_path
    assert_equal "star", category.reload[:icon_name]
  end

  test "shows a useful empty state" do
    @user.categories.destroy_all

    get categories_path

    assert_response :success
    assert_select "section[aria-labelledby='empty-categories-title']"
    assert_select "#empty-categories-title", text: "Lege deine erste Kategorie an"
    assert_select "a", text: "Erste Kategorie erstellen"
  end

  test "deletes an owned category and its sentences without touching another user" do
    category = @user.categories.create!(name: "Temporär", icon_name: "star")
    2.times do |index|
      @user.sentences.create!(
        content: "Temporärer Satz #{index}",
        category: category,
        language: languages(:de)
      )
    end
    other_sentence = sentences(:other_users_sentence)

    assert_difference -> { @user.categories.count }, -1 do
      assert_difference -> { @user.sentences.count }, -2 do
        delete category_path(id: category.id)
      end
    end

    assert_redirected_to categories_path
    assert Sentence.exists?(other_sentence.id)
  end
end
