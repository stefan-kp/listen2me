class Language < ApplicationRecord
  has_many :sentences
  
  validates :name, presence: true
  validates :code, presence: true, uniqueness: true, length: { is: 2 }

  def self.init_languages
    Language.create!(name: "English", code: "en") if Language.where(code: "en").empty?
    Language.create!(name: "German", code: "de") if Language.where(code: "de").empty?
  end
end 
