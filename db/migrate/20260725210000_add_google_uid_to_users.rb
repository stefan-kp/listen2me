class AddGoogleUidToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :google_uid, :string
    add_index :users,
      :google_uid,
      unique: true,
      where: "google_uid IS NOT NULL",
      name: "index_users_on_google_uid_unique"
    add_check_constraint :users,
      "google_uid IS NULL OR btrim(google_uid) <> ''",
      name: "users_google_uid_not_blank"
  end
end
