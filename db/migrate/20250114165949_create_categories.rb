class CreateCategories < ActiveRecord::Migration[7.1]
  def change
    create_table :categories do |t|
      t.string :name, null: false
      t.string :icon_name, null: false
      t.integer :usage_count, default: 0

      t.timestamps
    end

    # Add initial categories
    reversible do |dir|
      dir.up do
        default_categories = [
          ['Basic Needs', 'home'],           # Grundbedürfnisse - Haus-Symbol
          ['Food', 'cake'],                  # Essen - Kuchen-Symbol
          ['Drinks', 'beaker'],              # Getränke - Becher-Symbol
          ['Health', 'heart'],               # Gesundheit - Herz-Symbol
          ['Pain', 'exclamation-circle'],    # Schmerzen - Ausrufezeichen
          ['Bathroom', 'sparkles'],          # Toilette - Hygiene-Symbol
          ['Emotions', 'face-smile'],        # Gefühle - Lächelndes Gesicht
          ['Help', 'hand-raised'],           # Hilfe - Erhobene Hand
          ['Emergency', 'bell-alert'],       # Notfall - Alarmglocke
          ['Family', 'users'],               # Familie - Personen-Gruppe
          ['Daily Care', 'sun'],             # Tägliche Pflege - Sonne
          ['Rest', 'moon'],                  # Ruhe/Pause - Mond
          ['Entertainment', 'musical-note'],  # Unterhaltung - Musiknote
          ['Movement', 'arrow-path'],        # Bewegung - Bewegungspfeil
          ['Temperature', 'fire']            # Temperatur - Feuer-Symbol
        ]

        default_categories.each do |name, icon|
          Category.create!(name: name, icon_name: icon)
        end
      end
    end
  end
end
