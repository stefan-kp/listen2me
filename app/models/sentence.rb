class Sentence < ApplicationRecord
  belongs_to :user
  belongs_to :category, optional: true
  belongs_to :language

  validates :content, presence: true
  validates :language, presence: true

  before_create :set_initial_count

  def increment_usage!
    increment!(:usage_count)
    category&.increment_usage!
  end

  private

  def set_initial_count
    self.usage_count ||= 0
  end
end
