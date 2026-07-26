class Message < ApplicationRecord
  SPEAKER_CONTENT_LIMIT = 240
  PARTNER_CONTENT_LIMIT = 1_000

  belongs_to :conversation

  enum :role, speaker: 0, partner: 1

  validates :content, presence: true, length: { maximum: SPEAKER_CONTENT_LIMIT }, if: :speaker?
  validates :content, length: { maximum: PARTNER_CONTENT_LIMIT }, if: :partner?
  validates :role, presence: true

  def self.content_limit_for(role)
    role.to_s == "partner" ? PARTNER_CONTENT_LIMIT : SPEAKER_CONTENT_LIMIT
  end
end
