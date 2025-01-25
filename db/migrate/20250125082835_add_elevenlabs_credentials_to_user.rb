class AddElevenlabsCredentialsToUser < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :elevenlabs_api_key, :string
    rename_column :users, :voice_identifier, :elevenlabs_voice_id
    add_column :users, :llm_model, :string, default: "gpt-4o"
    add_column :users, :llm_provider, :string, default: "openai"
    add_column :users, :llm_api_key, :string
  end
end
