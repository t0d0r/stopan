ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "support/fake_google_oauth"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    def upload(name = "hello.txt", type = "text/plain")
      Rack::Test::UploadedFile.new(file_fixture(name), type)
    end
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  # Every test starts with empty sign-in and password reset counters
  # (specs/auth.md "Rate limits"); all test requests share one address.
  setup do
    Users::SessionsController::RATE_LIMIT_STORE.clear
    Users::PasswordsController::RATE_LIMIT_STORE.clear
  end
end
