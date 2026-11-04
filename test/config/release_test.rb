require "test_helper"

# Signed release tags (specs/release.md "Signed tags").
class ReleaseConfigTest < ActiveSupport::TestCase
  def read(path) = Rails.root.join(path).read

  test "allowed signers name the GitHub account, the git namespace and an ed25519 key, nothing more" do
    lines = read(".github/allowed_signers").lines.map(&:strip).reject { |line| line.empty? || line.start_with?("#") }
    assert_not_empty lines
    lines.each do |line|
      assert_match %r{\A[\w.-]+ (?:valid-before="\d{8}",)?namespaces="git" ssh-ed25519 [A-Za-z0-9+/]+={0,2}\z}, line
    end
  end

  test "make release signs the tag and verifies it before anything is pushed" do
    assert_match(/^release: .*\n\t@bin\/release \$\(VERSION\)$/, read("Makefile"))
    script = read("bin/release")
    sign = script.index("git tag -s")
    verify = script.index('gpg.ssh.allowedSignersFile="$signers" tag -v')
    push = script.index("git push origin")
    assert sign && verify && push, "bin/release must sign, verify and push"
    assert_operator sign, :<, verify
    assert_operator verify, :<, push
    assert_no_match(/git tag -a/, script)
  end
end
