class Message < ApplicationRecord
  belongs_to :conversation

  enum :role, speaker: 0, partner: 1

  validates :content, presence: true, length: { maximum: 240 }
  validates :role, presence: true
end
