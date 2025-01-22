class User < ApplicationRecord
  has_many :sentences, dependent: :destroy
  
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :voice_identifier, presence: true
end
