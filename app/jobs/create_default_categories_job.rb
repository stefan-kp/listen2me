require 'csv'
class CreateDefaultCategoriesJob < ApplicationJob
  queue_as :default

  def perform(user)
    Rails.logger.info "Creating default categories and sentences for user #{user.id}"
    
    # First create categories
    category_mapping = {}
    CSV.foreach(Rails.root.join('lib', 'assets', 'categories.csv'), headers: true) do |row|
      category = user.categories.find_or_initialize_by(name: row['name'])
      category.icon_name = row['icon_name']
      
      if category.save
        category_mapping[category.name] = category
        Rails.logger.info "Created/Updated category: #{category.name}"
      else
        Rails.logger.error "Error saving category #{category.name}: #{category.errors.full_messages.join(', ')}"
      end
    end
    
    # Then import sentences for each language
    %w[de en].each do |lang_code|
      language = Language.find_by!(code: lang_code)
      
      CSV.foreach(Rails.root.join('lib', 'assets', "sentences_#{lang_code}.csv"), headers: true) do |row|
        category = category_mapping[row['category']]
        next unless category
        
        sentence = user.sentences.find_or_initialize_by(
          content: row['content'],
          language: language
        )
        sentence.category = category
        
        if sentence.save
          Rails.logger.info "Created/Updated sentence: #{sentence.content}"
        else
          Rails.logger.error "Error saving sentence: #{sentence.errors.full_messages.join(', ')}"
        end
      end
    end
  end
end 