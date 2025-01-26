class AddLanguageToSentences < ActiveRecord::Migration[7.1]
  def change
    add_reference :sentences, :language, null: false, foreign_key: true
  end
end
