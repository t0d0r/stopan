# Which software runs: the version and commit date that bin/deploy wrote
# into REVISION when the image was built (specs/admin.md "Version").
# Without the file, as in development, both are nil.
class BuildInfo
  FILE = Rails.root.join("REVISION")
  VERSION_FORMAT = /\A[\w.+-]{1,60}\z/

  attr_reader :version, :committed_at

  def self.current
    @current ||= read(FILE)
  end

  def self.read(path)
    lines = File.exist?(path) ? File.read(path, 500).to_s.lines.map(&:strip) : []
    new(lines[0], lines[1])
  end

  def initialize(version, committed_at)
    @version = version if version.to_s.match?(VERSION_FORMAT)
    @committed_at = parse_time(committed_at) if @version
  end

  private

  def parse_time(value)
    Time.iso8601(value.to_s)
  rescue ArgumentError
    nil
  end
end
