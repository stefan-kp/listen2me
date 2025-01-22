class Category < ApplicationRecord
  has_many :sentences
  
  validates :name, presence: true, uniqueness: true
  validates :icon_name, presence: true
  
  def increment_usage!
    increment!(:usage_count)
  end
end
