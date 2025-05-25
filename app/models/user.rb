class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  has_many :conversations, dependent: :destroy
  has_many :sentences, dependent: :destroy
  has_many :categories, dependent: :destroy

  validates :first_name, presence: true
  validates :last_name, presence: true

  # Encrypt the LLM API key
  encrypts :llm_api_key

  # LLM Provider Settings
  ALLOWED_LLM_PROVIDERS = %w[openai anthropic gemini].freeze
  validates :llm_provider, 
            inclusion: { 
              in: ALLOWED_LLM_PROVIDERS, 
              message: "%{value} is not a supported LLM provider. Supported providers are: #{ALLOWED_LLM_PROVIDERS.join(', ')}." 
            },
            allow_nil: true # Depending on whether llm_provider can be nil (e.g. if there's a default or it's optional)

  after_create :create_default_categories

  private

  def create_default_categories
    CreateDefaultCategoriesJob.perform_later(self)
  end
end
