require "csv"

class DefaultContentInstaller
  LANGUAGE_NAMES = {
    "de" => "Deutsch",
    "en" => "English"
  }.freeze

  Result = Data.define(:categories, :sentences)

  def self.call(...)
    new(...).call
  end

  def initialize(user:)
    @user = user
  end

  def call
    categories = {}
    sentence_count = 0

    ApplicationRecord.transaction do
      languages = ensure_languages

      CSV.foreach(asset_path("categories.csv"), headers: true) do |row|
        category = @user.categories.find_or_initialize_by(name: row.fetch("name"))
        if category.new_record?
          category.icon_name = row.fetch("icon_name")
          category.save!
        end
        categories[category.name] = category
      end

      languages.each do |code, language|
        CSV.foreach(asset_path("sentences_#{code}.csv"), headers: true) do |row|
          category = categories.fetch(row.fetch("category"))
          sentence = @user.sentences.find_or_initialize_by(
            content: row.fetch("content"),
            language: language,
            category: category
          )
          sentence.save!
          sentence_count += 1
        end
      end
    end

    Result.new(categories: categories.size, sentences: sentence_count)
  end

  private

  def ensure_languages
    LANGUAGE_NAMES.to_h do |code, name|
      language = Language.find_or_initialize_by(code: code)
      language.name = name
      language.save!
      [ code, language ]
    end
  end

  def asset_path(filename)
    Rails.root.join("lib", "assets", filename)
  end
end
