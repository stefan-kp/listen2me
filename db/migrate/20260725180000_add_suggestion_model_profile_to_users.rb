class AddSuggestionModelProfileToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :suggestion_model_profile, :string, default: "fast", null: false
    add_check_constraint :users,
      "suggestion_model_profile IN ('fast', 'cheap')",
      name: "users_suggestion_model_profile_check"
  end
end
