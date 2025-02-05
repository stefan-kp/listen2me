require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :chrome, screen_size: [1400, 1400], options: {
    browser: :chrome,
    options: Selenium::WebDriver::Chrome::Options.new.tap { |opts|
      opts.add_argument('--headless')
      opts.add_argument('--disable-gpu')
      opts.add_argument('--no-sandbox')
    }
  }

  include Devise::Test::IntegrationHelpers
  include Warden::Test::Helpers

  def setup
    Warden.test_mode!
  end

  def teardown
    Warden.test_reset!
  end
end
