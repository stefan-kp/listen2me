class CreateSentences < ActiveRecord::Migration[7.1]
  def change
    create_table :sentences do |t|
      t.text :content, null: false
      t.integer :usage_count, default: 0
      t.references :user, null: false, foreign_key: true
      t.references :category, null: true, foreign_key: true

      t.timestamps
    end
  end
end
