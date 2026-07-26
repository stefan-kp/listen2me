require "test_helper"

class DefaultContentInstallerTest < ActiveSupport::TestCase
  test "new users receive all default categories and sentences" do
    user = create_user("complete")

    assert_equal 15, user.categories.count
    assert_equal 72, user.sentences.count
    assert_equal 36, user.sentences.joins(:language).where(languages: { code: "de" }).count
    assert_equal 36, user.sentences.joins(:language).where(languages: { code: "en" }).count
    assert_equal(
      user.id,
      user.sentences.find_by!(content: "Ich habe Durst").category.user_id
    )
  end

  test "installing default content repeatedly is idempotent" do
    user = create_user("idempotent")

    assert_no_difference -> { user.categories.count } do
      assert_no_difference -> { user.sentences.count } do
        result = DefaultContentInstaller.call(user: user)

        assert_equal 15, result.categories
        assert_equal 72, result.sentences
      end
    end

    assert_equal 15, user.categories.count
    assert_equal 72, user.sentences.count
  end

  test "default content remains isolated between users" do
    first_user = create_user("first")
    second_user = create_user("second")

    assert_equal 15, first_user.categories.count
    assert_equal 72, first_user.sentences.count
    assert_equal 15, second_user.categories.count
    assert_equal 72, second_user.sentences.count
    assert_not_equal(
      first_user.categories.find_by!(name: "Basic Needs").id,
      second_user.categories.find_by!(name: "Basic Needs").id
    )

    mismatched_sentences = Sentence.joins(:category)
      .where(user_id: [ first_user.id, second_user.id ])
      .where("sentences.user_id <> categories.user_id")

    assert_empty mismatched_sentences
  end

  test "backfill does not overwrite or move existing user content" do
    user = create_user("collision")
    language = Language.find_by!(code: "de")
    custom_category = user.categories.find_by!(name: "Basic Needs")
    custom_category.update!(icon_name: "star")
    custom_sentence = user.sentences.find_by!(
      content: "Ich brauche etwas",
      language: language,
      category: custom_category
    )
    other_category = user.categories.create!(name: "Mein Bereich", icon_name: "heart")
    same_text_elsewhere = user.sentences.create!(
      content: custom_sentence.content,
      language: language,
      category: other_category
    )

    DefaultContentInstaller.call(user: user)

    assert_equal "star", custom_category.reload.icon_name
    assert_equal custom_category, custom_sentence.reload.category
    assert_equal other_category, same_text_elsewhere.reload.category
    assert_equal 2, user.sentences.where(content: custom_sentence.content, language: language).count
  end

  private

  def create_user(suffix)
    User.create!(
      email: "defaults-#{suffix}@example.com",
      password: "password123",
      first_name: "Default",
      last_name: "Tester"
    )
  end
end
