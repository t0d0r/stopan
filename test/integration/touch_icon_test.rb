require "test_helper"

# iOS and macOS ask for the precomposed name first (specs/ui.md "Chosen").
class TouchIconTest < ActiveSupport::TestCase
  test "the precomposed touch icon is a copy of the touch icon" do
    assert_equal Rails.public_path.join("apple-touch-icon.png").binread,
                 Rails.public_path.join("apple-touch-icon-precomposed.png").binread
  end
end
