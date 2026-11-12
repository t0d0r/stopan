require "test_helper"

# specs/admin.md "Version"
class BuildInfoTest < ActiveSupport::TestCase
  def read(content)
    file = Tempfile.new("REVISION")
    file.write(content)
    file.close
    BuildInfo.read(file.path)
  ensure
    file.unlink
  end

  test "reads the version and the commit date" do
    build = read("v0.1.1-35-g98e4114\n2026-11-12T14:30:00+02:00\n")
    assert_equal "v0.1.1-35-g98e4114", build.version
    assert_equal Time.utc(2026, 11, 12, 12, 30), build.committed_at
  end

  test "a version without a date, and a date that does not parse" do
    assert_nil read("v0.2.0\n").committed_at
    build = read("v0.2.0\nyesterday\n")
    assert_equal "v0.2.0", build.version
    assert_nil build.committed_at
  end

  test "anything that is not a plain version counts as missing" do
    [ "", "\n2026-11-12T14:30:00+02:00\n", "<script>alert(1)</script>\n", "v1 beta\n", "#{'9' * 61}\n" ].each do |content|
      build = read(content)
      assert_nil build.version, content
      assert_nil build.committed_at, content
    end
  end

  test "a missing file gives no version" do
    build = BuildInfo.read(Rails.root.join("tmp/no-such-REVISION"))
    assert_nil build.version
    assert_nil build.committed_at
  end

  test "the tree has no REVISION file of its own" do
    assert_nil BuildInfo.current.version
  end
end
