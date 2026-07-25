require "application_system_test_case"

class CategoriesTest < ApplicationSystemTestCase
  def setup
    @user = users(:default_user)
    @category = categories(:test_category)
    sign_in @user
  end

  test "visiting the categories index" do
    visit categories_path

    assert_selector "h1", text: "Kategorien verwalten"
    assert_selector "a", text: "Neue Kategorie"
  end

  test "creating a new category" do
    visit categories_path
    click_on "Neue Kategorie"

    fill_in "Name", with: "Essen & Trinken"
    find("label[for='category_icon_name_heart']").click

    click_on "Kategorie erstellen"

    assert_text "Die Kategorie „Essen & Trinken“ wurde erstellt."
    assert_selector "h2", text: "Essen & Trinken"
  end

  test "updating a category" do
    visit categories_path

    within "#category_#{@category.id}" do
      click_on "Bearbeiten"
    end

    fill_in "Name", with: "Geänderter Name"
    click_on "Änderungen speichern"

    assert_text "Die Kategorie „Geänderter Name“ wurde gespeichert."
    assert_selector "h2", text: "Geänderter Name"
  end

  test "deleting a category also deletes its sentences after confirmation" do
    category_to_delete = categories(:category_to_delete)
    sentence = @user.sentences.create!(
      content: "Dieser Satz wird mitgelöscht",
      category: category_to_delete,
      language: languages(:de)
    )

    visit categories_path

    accept_confirm do
      within "#category_#{category_to_delete.id}" do
        click_on "Löschen"
      end
    end

    assert_text "Die Kategorie „Zu löschen“ und ein Satz wurden gelöscht."
    assert_no_selector "#category_#{category_to_delete.id}"
    assert_not Sentence.exists?(sentence.id)
  end
end
