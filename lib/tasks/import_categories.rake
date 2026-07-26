namespace :import do
  desc "Import categories from CSV file"
  task categories: :environment do
    abort "No users found. Create an account first." unless User.exists?

    User.find_each do |user|
      result = DefaultContentInstaller.call(user: user)
      puts "Defaults ready for user #{user.id}: #{result.categories} categories, #{result.sentences} sentences"
    end
  end
end
