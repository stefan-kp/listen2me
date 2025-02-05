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

    assert_text "Kategorie wurde erstellt"
    assert_selector "p", text: "Essen & Trinken"
  end

  test "updating a category" do
    visit categories_path
    
    within "#category_#{@category.id}" do
      find(".group").hover
      find("#edit_category_#{@category.id}").click
    end

    fill_in "Name", with: "Geänderter Name"
    click_on "Änderungen speichern"

    assert_text "Kategorie wurde erfolgreich aktualisiert"
    assert_selector "p", text: "Geänderter Name"
  end

  test "deleting a category" do
    category_to_delete = categories(:category_to_delete)
    
    visit categories_path
    
    accept_confirm do
      within "#category_#{category_to_delete.id}" do
        find(".group").hover
        find("#delete_category_#{category_to_delete.id}").click
      end
    end

    assert_text "Kategorie wurde gelöscht"
    assert_no_text "Zu löschen"
  end
end 