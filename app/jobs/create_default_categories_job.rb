class CreateDefaultCategoriesJob < ApplicationJob
  queue_as :default

  def perform(user)
    result = DefaultContentInstaller.call(user: user)
    Rails.logger.info(
      "Default content ready for user #{user.id} " \
      "(#{result.categories} categories, #{result.sentences} sentences)"
    )
  end
end
