class CreateLanguages < ActiveRecord::Migration[7.1]
  def change
    create_table :languages do |t|
      t.string :name, null: false
      t.string :code, null: false

      t.timestamps
    end

    add_index :languages, :code, unique: true

    reversible do |dir|
      dir.up do
        execute <<~SQL
          INSERT INTO languages (name, code, created_at, updated_at)
          VALUES
            ('Deutsch', 'de', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
            ('English', 'en', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
          ON CONFLICT (code) DO NOTHING
        SQL
      end
    end
  end
end
