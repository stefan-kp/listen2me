class ConversationSummary < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :conversation_summary, :jsonb
    add_column :users, :summary_generated_at, :datetime
    add_index :users, :summary_generated_at
  end
end
