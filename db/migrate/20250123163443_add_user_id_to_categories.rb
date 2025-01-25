class AddUserIdToCategories < ActiveRecord::Migration[8.0]
  def change
    add_column :categories, :user_id, :integer
    reversible do |dir|
      dir.up do
        Category.update_all(user_id: User.first.id)
        change_column_null :categories, :user_id, false
        add_foreign_key :categories, :users, dependent: :destroy
      end
    end
  end
end
