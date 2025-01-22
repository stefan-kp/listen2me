class CreateGeneralCategory < ActiveRecord::Migration[8.0]
  def up
    Category.create!(name: 'General', icon_name: 'squares-plus')
  end

  def down
    Category.find_by(name: 'General')&.destroy
  end
end
