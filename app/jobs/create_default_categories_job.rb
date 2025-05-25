require "csv"
class CreateDefaultCategoriesJob < ApplicationJob
  queue_as :default

  def perform(user)
    Rails.logger.info "Creating default categories and sentences for user #{user.id}"

    # First create categories
    category_mapping = {}
    CSV.foreach(Rails.root.join("lib", "assets", "categories.csv"), headers: true) do |row|
      category = user.categories.find_or_initialize_by(name: row["name"])
      category.icon_name = row["icon_name"]

      if category.save
        category_mapping[category.name] = category
        Rails.logger.info "Created/Updated category: #{category.name}"
      else
        Rails.logger.error "Error saving category #{category.name}: #{category.errors.full_messages.join(', ')}"
      end
    end

    # Then import sentences for each language
    language_codes = Language.pluck(:code)
    if language_codes.empty?
      Rails.logger.error "No languages found in the database. Cannot create default sentences."
      # Consider re-raising an error here if job retries are configured
      # raise "No languages found"
      return # or raise an error
    end

    language_codes.each do |lang_code|
      ActiveRecord::Base.transaction do
        language = Language.find_by(code: lang_code)
        unless language
          Rails.logger.error "Language with code '#{lang_code}' not found. Skipping sentence import for this language."
          next # Skip to the next language
        end

        Rails.logger.info "Processing sentences for language: #{lang_code}"
        csv_path = Rails.root.join("lib", "assets", "sentences_#{lang_code}.csv")
        unless File.exist?(csv_path)
          Rails.logger.warn "CSV file not found for language '#{lang_code}' at #{csv_path}. Skipping sentence import for this language."
          next # Skip to the next language
        end

        CSV.foreach(csv_path, headers: true) do |row|
          category_name = row["category"]
          category = category_mapping[category_name]
          unless category
            Rails.logger.warn "Category '#{category_name}' not found in mapping. Skipping sentence: #{row['content']}"
            next
          end

          sentence = user.sentences.find_or_initialize_by(
            content: row["content"],
            language: language
          )
          sentence.category = category

          if sentence.save
            Rails.logger.info "Created/Updated sentence: #{sentence.content} for language: #{lang_code}"
          else
            Rails.logger.error "Error saving sentence: #{sentence.errors.full_messages.join(', ')} for content: #{row['content']}, language: #{lang_code}"
            # If a sentence fails to save, the transaction will ensure atomicity for this language's sentences.
            # Depending on requirements, you might want to raise an error to rollback the transaction for this language.
            # For now, we log the error and continue processing other sentences for this language.
          end
        end
      rescue ActiveRecord::RecordNotFound => e
        Rails.logger.error "Failed to find language with code '#{lang_code}'. Error: #{e.message}"
        # This specific rescue block for RecordNotFound might be redundant if using find_by and checking for nil language
        # but kept for explicitness if find_by! were to be used or other similar errors could occur.
      rescue StandardError => e
        Rails.logger.error "An error occurred during sentence processing for language '#{lang_code}': #{e.message}"
        # This will rollback the transaction for the current language
        raise e # Re-raise to ensure the transaction for this language is rolled back
      end
    end
    Rails.logger.info "Finished creating default categories and sentences for user #{user.id}"
  end
end
