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
        Language.create!([
          { name: 'Deutsch', code: 'de' },
          { name: 'English', code: 'en' }
        ])
      end
    end
  end
end 