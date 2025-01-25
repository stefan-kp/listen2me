namespace :import do
  desc 'Import sentences from CSV files'
  task sentences: :environment do
    require 'csv'
    
    def import_sentences(file_path, language_code)
      language = Language.find_by!(code: language_code)
      
      CSV.foreach(file_path, headers: true) do |row|
        category = Category.find_by!(name: row['category'])
        
        # Find existing sentence by content and language
        existing_sentence = Sentence.find_by(
          content: row['content'],
          language: language,
          user: User.first
        )
        
        if existing_sentence
          # Update category if sentence exists
          existing_sentence.update!(category: category)
          puts "Updated: #{row['content']}"
        else
          # Create new sentence if it doesn't exist
          sentence = Sentence.create!(
            category: Category.find_by!(name: row['category']) || Category.find_by!(name: 'General'),
            content: row['content'],
            user: User.first,
            language: language
          )
          puts "Created: #{row['content']}"
        end
      end
    end

    # Create default user if none exists
    User.create!(
      first_name: 'Christoph',
      last_name: '-',
      voice_identifier: 'Christoph'
    ) if User.count == 0

    puts 'Importing German sentences...'
    import_sentences(Rails.root.join('lib', 'assets', 'sentences_de.csv'), 'de')
    
    puts 'Importing English sentences...'
    import_sentences(Rails.root.join('lib', 'assets', 'sentences_en.csv'), 'en')
    
    puts 'Import completed!'
  end
end 