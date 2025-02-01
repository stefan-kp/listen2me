class RmNotNullInitialSentenses < ActiveRecord::Migration[8.0]
  def change
    change_column_null :conversations, :initial_sentence_id, true
    
    # Füge ON DELETE SET NULL für die initial_sentence_id hinzu
    remove_foreign_key :conversations, :sentences
    add_foreign_key :conversations, :sentences, column: :initial_sentence_id, on_delete: :nullify
  end
end
