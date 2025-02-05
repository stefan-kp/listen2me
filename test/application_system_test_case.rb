require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome

  include Devise::Test::IntegrationHelpers
  include Warden::Test::Helpers

  def setup
    Warden.test_mode!
  end

  def teardown
    Warden.test_reset!
  end
end
