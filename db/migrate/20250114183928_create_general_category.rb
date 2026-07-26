class CreateGeneralCategory < ActiveRecord::Migration[8.0]
  def up
    # Categories are user-owned. A global category created during migration
    # cannot be assigned safely because a fresh database has no users yet.
    # Default categories are created when a user is created.
  end

  def down
  end
end
