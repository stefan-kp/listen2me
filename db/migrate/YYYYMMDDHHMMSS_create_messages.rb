class CreateMessages < ActiveRecord::Migration[7.1]
  def change
    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.text :content, null: false
      t.integer :role, null: false, default: 0

      t.timestamps
    end
  end
end 