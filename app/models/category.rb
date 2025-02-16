class Category < ApplicationRecord
  has_many :sentences

  validates :name, presence: true
  validates :icon_name, presence: true
  belongs_to :user

  def increment_usage!
    increment!(:usage_count)
  end

  ICONS = %w[
            heart bell user-group home hand-raised star face-smile
            exclamation-circle information-circle question-mark-circle check-circle
            sun moon clock calendar calendar-days
            speaker-wave microphone video-camera phone
            book-open pencil pencil-square document
            shopping-cart shopping-bag gift cake
            arrow-path arrows-right-left arrow-trending-up arrow-trending-down
            cog wrench key shield-check
            user user-circle user-group user-plus user-minus
            chat-bubble-left chat-bubble-left-right megaphone
            light-bulb sparkles bolt trophy
            building-office building-storefront building-library
            map-pin globe-americas globe-europe-africa globe-asia-australia
            device-phone-mobile computer-desktop printer
            lock-closed lock-open eye eye-slash
            play pause stop forward backward
            plus minus plus-circle minus-circle
            check x-mark trash
          ]
end
