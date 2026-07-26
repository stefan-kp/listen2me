class Category < ApplicationRecord
  ICONS = %w[
    home
    cake
    beaker
    heart
    exclamation-circle
    sparkles
    face-smile
    hand-raised
    bell-alert
    user-group
    sun
    moon
    musical-note
    arrow-path
    fire
    star
  ].freeze

  DEFAULT_ICON = "star"
  ICON_ALIASES = { "users" => "user-group" }.freeze
  LEGACY_ICONS = %w[
    bell
    information-circle
    question-mark-circle
    check-circle
    clock
    calendar
    calendar-days
    speaker-wave
    microphone
    video-camera
    phone
    book-open
    pencil
    pencil-square
    document
    shopping-cart
    shopping-bag
    gift
    arrows-right-left
    arrow-trending-up
    arrow-trending-down
    cog
    wrench
    key
    shield-check
    user
    user-circle
    user-plus
    user-minus
    chat-bubble-left
    chat-bubble-left-right
    megaphone
    light-bulb
    bolt
    building-office
    building-storefront
    building-library
    map-pin
    globe-americas
    globe-europe-africa
    globe-asia-australia
    device-phone-mobile
    computer-desktop
    printer
    lock-closed
    lock-open
    eye
    eye-slash
    play
    pause
    stop
    forward
    backward
    plus
    minus
    plus-circle
    minus-circle
    check
    x-mark
    trash
  ].freeze
  DISPLAYABLE_ICONS = (ICONS + LEGACY_ICONS).freeze

  has_many :sentences, dependent: :destroy
  belongs_to :user

  validates :name, presence: true, length: { maximum: 60 }
  validate :icon_name_is_selectable

  before_validation :normalize_name
  before_validation :normalize_icon_name

  def increment_usage!
    increment!(:usage_count)
  end

  def icon_name_for_display
    DISPLAYABLE_ICONS.include?(stored_icon_name) ? stored_icon_name : DEFAULT_ICON
  end

  def icon_name
    icon_name_for_display
  end

  def legacy_icon_name
    LEGACY_ICONS.include?(stored_icon_name) ? stored_icon_name : nil
  end

  def self.canonical_icon_name(value)
    normalized = value.to_s.strip
    return if normalized.blank?

    ICON_ALIASES.fetch(normalized, normalized)
  end

  private

  def stored_icon_name
    self.class.canonical_icon_name(self[:icon_name])
  end

  def icon_name_is_selectable
    return if ICONS.include?(stored_icon_name)
    return if persisted? && !will_save_change_to_icon_name?

    errors.add(:icon_name, :inclusion)
  end

  def normalize_name
    self.name = name.to_s.strip
  end

  def normalize_icon_name
    self[:icon_name] = self.class.canonical_icon_name(self[:icon_name])
  end
end
