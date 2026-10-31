require "test_helper"
require "puma/configuration"

# The request size limit in config/puma.rb (specs/attachments.md
# "Request size"): read from the real file, as Puma reads it.
class PumaConfigTest < ActiveSupport::TestCase
  def limit_with(value)
    saved = ENV["MAX_REQUEST_BODY"]
    value.nil? ? ENV.delete("MAX_REQUEST_BODY") : ENV["MAX_REQUEST_BODY"] = value
    config = Puma::Configuration.new(config_files: [ Rails.root.join("config/puma.rb").to_s ])
    config.load
    config._options[:http_content_length_limit]
  ensure
    saved.nil? ? ENV.delete("MAX_REQUEST_BODY") : ENV["MAX_REQUEST_BODY"] = saved
  end

  test "the default leaves room for the largest allowed upload and the form's text" do
    limit = limit_with(nil)
    assert_equal 52.megabytes, limit
    assert_operator limit, :>=, Attachable::MAX_FILES * Attachable::MAX_SIZE + 2.megabytes
  end

  test "MAX_REQUEST_BODY sets the limit, 0 turns it off, anything else stops the server" do
    assert_equal 1_000, limit_with("1000")
    assert_nil limit_with("0")
    assert_raises(ArgumentError) { limit_with("lots") }
    assert_raises(ArgumentError) { limit_with("-1") }
  end

  test "the Docker image gives Thruster the same default" do
    assert_match(/^ENV MAX_REQUEST_BODY="#{52.megabytes}"$/, Rails.root.join("Dockerfile").read)
  end
end
