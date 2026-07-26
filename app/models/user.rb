class User < ApplicationRecord
  PREFERRED_LOCALES = %w[de en].freeze
  PREFERRED_SPEECH_MODES = %w[direct draft].freeze
  SUGGESTION_MODEL_PROFILES = %w[fast cheap].freeze
  SPEECH_PROVIDERS = %w[openai browser cartesia elevenlabs].freeze

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: [ :google_oauth2 ]
  has_many :conversations, dependent: :destroy
  has_many :sentences, dependent: :destroy
  has_many :categories, dependent: :destroy

  encrypts :elevenlabs_api_key, :llm_api_key

  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :preferred_locale, inclusion: { in: PREFERRED_LOCALES }
  validates :preferred_speech_mode, inclusion: { in: PREFERRED_SPEECH_MODES }
  validates :suggestion_model_profile, inclusion: { in: SUGGESTION_MODEL_PROFILES }
  validates :speech_provider, inclusion: { in: SPEECH_PROVIDERS }
  validates :google_uid, uniqueness: true, length: { maximum: 255 }, allow_nil: true
  validate :google_uid_is_not_blank

  after_create :create_default_categories

  def onboarding_completed?
    onboarding_completed_at.present?
  end

  def google_connected?
    google_uid.present?
  end

  def self.google_oauth_configured?
    ENV["GOOGLE_CLIENT_ID"].present? && ENV["GOOGLE_CLIENT_SECRET"].present?
  end

  private

  def create_default_categories
    CreateDefaultCategoriesJob.perform_now(self)
  end

  def google_uid_is_not_blank
    errors.add(:google_uid, :blank) if google_uid == ""
  end
end
