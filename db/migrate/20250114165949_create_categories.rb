class CreateCategories < ActiveRecord::Migration[7.1]
  def change
    create_table :categories do |t|
      t.string :name, null: false
      t.string :icon_name, null: false
      t.integer :usage_count, default: 0

      t.timestamps
    end
  end
end
