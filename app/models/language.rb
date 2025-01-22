class Language < ApplicationRecord
  has_many :sentences
  
  validates :name, presence: true
  validates :code, presence: true, uniqueness: true, length: { is: 2 }
end 