class HardenCategoryOwnership < ActiveRecord::Migration[8.0]
  def up
    change_column :categories, :user_id, :bigint unless column_for(:categories, :user_id).type == :bigint
    add_index :categories, :user_id unless index_exists?(:categories, :user_id)

    remove_foreign_key :categories, :users if foreign_key_exists?(:categories, :users)
    add_foreign_key :categories, :users, on_delete: :cascade
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def column_for(table, column)
    connection.columns(table).find { |candidate| candidate.name == column.to_s }
  end
end
