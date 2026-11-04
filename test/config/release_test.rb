require "test_helper"

# Signed release tags and files (specs/release.md "Signed tags" and
# "Signed release files").
class ReleaseConfigTest < ActiveSupport::TestCase
  def read(path) = Rails.root.join(path).read

  test "allowed signers name the GitHub account, the git and file namespaces and an ed25519 key, nothing more" do
    lines = read(".github/allowed_signers").lines.map(&:strip).reject { |line| line.empty? || line.start_with?("#") }
    assert_not_empty lines
    lines.each do |line|
      assert_match %r{\A[\w.-]+ (?:valid-before="\d{8}",)?namespaces="git,file" ssh-ed25519 [A-Za-z0-9+/]+={0,2}\z}, line
    end
  end

  test "make release signs the tag and the release files and verifies both before anything is pushed" do
    makefile = read("Makefile")
    assert_match(/^release: .*\n\t@bin\/release \$\(VERSION\)$/, makefile)
    assert_match(/^release-files: .*\n\t@bin\/release --files \$\(VERSION\)$/, makefile)
    script = read("bin/release")
    main = script[script.index("make check")..]
    steps = [ "git tag -s", 'gpg.ssh.allowedSignersFile="$signers" tag -v', "files=$(release_files)", "git push origin", "gh release create" ]
    positions = steps.map { |step| main.index(step) }
    assert positions.all?, "bin/release must sign and verify the tag and the files, then push and publish"
    assert_equal positions.sort, positions
    assert_no_match(/git tag -a/, script)
  end

  test "release files come from the tag and are signed in the file namespace and verified" do
    files = read("bin/release")[/release_files\(\) \{.*?\n\}/m]
    assert_includes files, 'git archive --format=tar.gz --prefix="stopan-$version/" -o "$archive" "$tag"'
    assert_includes files, 'ssh-keygen -q -Y sign -f "$key" -n file "$archive"'
    assert_includes files, 'ssh-keygen -Y verify -f "$signers" -I "$principal" -n file'
  end
end
