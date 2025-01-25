class Category < ApplicationRecord
  has_many :sentences
  
  validates :name, presence: true
  validates :icon_name, presence: true
  belongs_to :user
  
  def increment_usage!
    increment!(:usage_count)
  end
end
