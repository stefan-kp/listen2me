class CreateConversations < ActiveRecord::Migration[7.1]
  def change
    create_table :conversations do |t|
      t.references :user, null: false, foreign_key: true
      t.references :initial_sentence, null: false, foreign_key: { to_table: :sentences }
      t.boolean :active, default: true

      t.timestamps
    end
  end
end 