class AddOnboardingPreferencesToUsers < ActiveRecord::Migration[8.0]
  def up
    add_column :users, :preferred_locale, :string, default: "de", null: false
    add_column :users, :preferred_speech_mode, :string, default: "direct", null: false
    add_column :users, :onboarding_completed_at, :datetime

    # Existing accounts keep their current workflow. Newly registered accounts
    # have no completion timestamp and are guided through onboarding once.
    execute <<~SQL.squish
      UPDATE users
      SET onboarding_completed_at = CURRENT_TIMESTAMP
    SQL
  end

  def down
    remove_column :users, :onboarding_completed_at
    remove_column :users, :preferred_speech_mode
    remove_column :users, :preferred_locale
  end
end
