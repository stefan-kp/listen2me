namespace :import do
  desc 'Import categories from CSV file'
  task categories: :environment do
    require 'csv'
    
    puts 'Importing categories...'
    
    # Create default user if none exists
    user = User.first_or_create!(
      first_name: 'Christoph',
      last_name: '-',
      voice_identifier: 'Christoph'
    )
    
    CSV.foreach(Rails.root.join('lib', 'assets', 'categories.csv'), headers: true) do |row|
      category = Category.find_or_initialize_by(name: row['name'])
      category.icon_name = row['icon_name']
      category.user = user
      
      if category.save
        puts "Created/Updated: #{category.name}"
      else
        puts "Error saving #{category.name}: #{category.errors.full_messages.join(', ')}"
      end
    end
    
    puts 'Import completed!'
  end
end 