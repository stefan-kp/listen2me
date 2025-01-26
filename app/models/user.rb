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

  after_create :create_default_categories

  private

  def create_default_categories
    CreateDefaultCategoriesJob.perform_now(self)
  end
end
