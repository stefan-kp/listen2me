require "test_helper"
require "csv"

class CategoryTest < ActiveSupport::TestCase
  test "curated icons include every default content icon" do
    seed_icons = CSV.read(
      Rails.root.join("lib/assets/categories.csv"),
      headers: true
    ).filter_map { |row| Category.canonical_icon_name(row["icon_name"]) }.uniq

    assert_empty seed_icons - Category::ICONS
  end

  test "every allowlisted display icon exists in the installed Heroicon set" do
    missing_icons = Category::DISPLAYABLE_ICONS.reject do |icon_name|
      Rails.application.assets.load_path.find("heroicon/outline/#{icon_name}.svg")
    end

    assert_empty missing_icons
  end

  test "normalizes the legacy users icon to user-group" do
    category = users(:default_user).categories.build(
      name: "Menschen",
      icon_name: "users"
    )

    assert_predicate category, :valid?
    assert_equal "user-group", category.icon_name
    assert_equal "user-group", category.icon_name_for_display

    category.save!
    assert_equal "user-group", category[:icon_name]
  end

  test "rejects unsupported icons and offers a safe display fallback" do
    category = users(:default_user).categories.build(
      name: "Manipuliertes Symbol",
      icon_name: "not-a-real-icon"
    )

    assert_not category.valid?
    assert category.errors.of_kind?(:icon_name, :inclusion)
    assert_equal Category::DEFAULT_ICON, category.icon_name
    assert_equal Category::DEFAULT_ICON, category.icon_name_for_display
  end

  test "an unchanged valid legacy icon does not block renaming" do
    category = categories(:category_to_delete)

    assert_equal "trash", category.icon_name
    assert category.update(name: "Neuer Name")
    assert_equal "trash", category[:icon_name]
  end

  test "an unknown stored icon has a safe global fallback" do
    category = categories(:test_category)
    category.update_column(:icon_name, "not-a-real-icon")

    assert_equal Category::DEFAULT_ICON, category.reload.icon_name
    assert_nil category.legacy_icon_name
  end

  test "normalizes the category name" do
    category = users(:default_user).categories.create!(
      name: "  Familie  ",
      icon_name: "users"
    )

    assert_equal "Familie", category.name
  end

  test "destroying a category destroys its sentences" do
    user = users(:default_user)
    category = user.categories.create!(name: "Temporär", icon_name: "star")
    sentence = user.sentences.create!(
      content: "Temporärer Satz",
      category: category,
      language: languages(:de)
    )

    assert_difference "Category.count", -1 do
      assert_difference "Sentence.count", -1 do
        category.destroy!
      end
    end

    assert_not Sentence.exists?(sentence.id)
  end
end
