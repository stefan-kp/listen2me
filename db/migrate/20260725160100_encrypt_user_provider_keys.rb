class EncryptUserProviderKeys < ActiveRecord::Migration[8.0]
  COLUMNS = %w[elevenlabs_api_key llm_api_key].freeze

  class EncryptedUser < ActiveRecord::Base
    self.table_name = "users"

    encrypts :elevenlabs_api_key, :llm_api_key
  end

  def up
    EncryptedUser.reset_column_information
    encrypted_types = COLUMNS.index_with { |name| EncryptedUser.type_for_attribute(name) }

    select_all("SELECT id, #{COLUMNS.join(', ')} FROM users").each do |row|
      updates = COLUMNS.each_with_object({}) do |name, values|
        raw_value = row[name]
        values[name] = raw_value unless raw_value.nil? || encrypted_types.fetch(name).encrypted?(raw_value)
      end

      EncryptedUser.where(id: row.fetch("id")).update_all(updates) if updates.any?
    end

    EncryptedUser.find_each do |user|
      COLUMNS.each { |name| user.public_send(name) }
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
