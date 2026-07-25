class AddSpeechProviderToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :speech_provider, :string, default: "openai", null: false
    add_check_constraint :users,
      "speech_provider IN ('openai', 'browser', 'cartesia', 'elevenlabs')",
      name: "users_speech_provider_check"
  end
end
