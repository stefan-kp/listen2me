class Conversation < ApplicationRecord
  belongs_to :user
  belongs_to :initial_sentence, class_name: "Sentence"
  has_many :messages, dependent: :destroy

  validates :user, presence: true
  validates :initial_sentence, presence: true
end
