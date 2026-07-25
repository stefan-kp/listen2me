class AddUserIdToCategories < ActiveRecord::Migration[8.0]
  def up
    add_reference :categories, :user, type: :bigint, index: true
    backfill_legacy_categories!
    change_column_null :categories, :user_id, false
    add_foreign_key :categories, :users, on_delete: :cascade
  end

  def down
    remove_foreign_key :categories, :users
    remove_reference :categories, :user, index: true
  end

  private

  def backfill_legacy_categories!
    return unless select_value("SELECT COUNT(*) FROM categories WHERE user_id IS NULL").to_i.positive?

    user_ids = select_values("SELECT id FROM users ORDER BY id LIMIT 2")

    unless user_ids.one?
      raise ActiveRecord::MigrationError,
        "Legacy categories need exactly one existing user for an unambiguous backfill"
    end

    execute <<~SQL
      UPDATE categories
      SET user_id = #{connection.quote(user_ids.first)}
      WHERE user_id IS NULL
    SQL
  end
end
