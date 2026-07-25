class User < ApplicationRecord
  PREFERRED_LOCALES = %w[de en].freeze
  PREFERRED_SPEECH_MODES = %w[direct draft].freeze

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  has_many :conversations, dependent: :destroy
  has_many :sentences, dependent: :destroy
  has_many :categories, dependent: :destroy

  encrypts :elevenlabs_api_key, :llm_api_key

  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :preferred_locale, inclusion: { in: PREFERRED_LOCALES }
  validates :preferred_speech_mode, inclusion: { in: PREFERRED_SPEECH_MODES }

  after_create :create_default_categories

  def onboarding_completed?
    onboarding_completed_at.present?
  end

  private

  def create_default_categories
    CreateDefaultCategoriesJob.perform_now(self)
  end
end
