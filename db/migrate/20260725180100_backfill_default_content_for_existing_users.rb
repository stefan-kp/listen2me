class BackfillDefaultContentForExistingUsers < ActiveRecord::Migration[8.0]
  def up
    User.find_each do |user|
      DefaultContentInstaller.call(user: user)
    end
  end

  def down
  end
end
