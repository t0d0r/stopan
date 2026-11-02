require "test_helper"

# Base images are pinned by digest (specs/docker.md "Pinned base images").
class DockerfileTest < ActiveSupport::TestCase
  FILES = %w[Dockerfile Dockerfile.dev].freeze
  DIGEST = /@sha256:\h{64}\b/

  def read(name) = Rails.root.join(name).read

  test "every image is pinned by digest; later stages build on the pinned base" do
    FILES.each do |name|
      text = read(name)
      assert_match(/\A# syntax=docker\/dockerfile:1#{DIGEST}$/, text, "#{name}: the syntax frontend is not pinned")
      text.scan(/^FROM\s+(\S+)/).flatten.each do |image|
        assert image.match?(DIGEST) || image == "base", "#{name}: FROM #{image} is not pinned by digest"
      end
    end
  end

  test "both Dockerfiles use the same Ruby image, the version of .ruby-version" do
    version = Rails.root.join(".ruby-version").read.strip.delete_prefix("ruby-")
    digests = FILES.map do |name|
      text = read(name)
      assert_includes text, "# ruby:#{version}-slim,", "#{name}: the comment names another Ruby version"
      text[/^FROM docker\.io\/library\/ruby(@sha256:\h{64})/, 1]
    end
    assert_equal 1, digests.uniq.size, "the Dockerfiles use different Ruby digests"
    assert digests.first
  end
end
