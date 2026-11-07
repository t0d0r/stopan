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

  test "make release signs and verifies the tag before it pushes it, and publishes only checked and signed files" do
    makefile = read("Makefile")
    assert_match(/^release: .*\n\t@bin\/release \$\(VERSION\)$/, makefile)
    assert_match(/^release-files: .*\n\t@bin\/release --files \$\(VERSION\)$/, makefile)
    script = read("bin/release")
    main = script[script.index("\nmake check\n")..]
    steps = [ "git tag -s", 'gpg.ssh.allowedSignersFile="$signers" tag -v', "write_notes", "git push origin", 'files=$(release_files "$run")', "gh release create" ]
    positions = steps.map { |step| main.index(step) }
    assert positions.all?, "bin/release must sign and verify the tag, push it, then check and sign the files before it publishes"
    assert_equal positions.sort, positions
    assert_no_match(/git tag -a/, script)
  end

  test "release files come from the release build and are checked before the archive is signed" do
    files = read("bin/release")[/release_files\(\) \{.*?\n\}/m]
    checks = [
      'gh run watch "$run" --exit-status',
      'gh run download "$run" --name release-files',
      'gh attestation verify "$archive" --bundle "$archive.intoto.jsonl" --repo "$repo"',
      '--signer-workflow "$repo/.github/workflows/$workflow" --source-ref "$source_ref" --source-digest "$sha"',
      'gzip -dc "$archive" | cmp -s - <(git -c tar.umask=0002 archive --format=tar --prefix="stopan-$version/" "$tag")',
      'ssh-keygen -q -Y sign -f "$key" -n file "$archive"',
      'ssh-keygen -Y verify -f "$signers" -I "$principal" -n file'
    ]
    positions = checks.map { |check| files.index(check) }
    assert positions.all?, "release_files must wait, download, verify the provenance and the content, then sign"
    assert_equal positions.sort, positions
    assert_no_match(/--format=tar\.gz/, files, "the archive is built by the release build, not on this machine")
  end

  test "the release build builds the tag with signed provenance and writes nothing to the repository" do
    workflow = YAML.load_file(Rails.root.join(".github/workflows/release.yml"))
    triggers = workflow[true] # YAML 1.1 reads the key "on" as true
    assert_equal [ "v[0-9]+.[0-9]+.[0-9]+" ], triggers.dig("push", "tags")
    assert_equal [ "tag" ], triggers.dig("workflow_dispatch", "inputs").keys
    assert_equal({}, workflow["permissions"])
    assert_equal [ "build" ], workflow["jobs"].keys
    build = workflow.dig("jobs", "build")
    assert_equal({ "contents" => "read", "id-token" => "write", "attestations" => "write" }, build["permissions"])

    steps = build["steps"]
    assert_equal %w[actions/checkout actions/attest-build-provenance actions/upload-artifact], steps.filter_map { it["uses"]&.split("@")&.first }
    assert_equal false, steps.find { it["uses"]&.start_with?("actions/checkout@") }.dig("with", "persist-credentials")
    assert_equal "release-files", steps.find { it["uses"]&.start_with?("actions/upload-artifact@") }.dig("with", "name")
    scripts = steps.filter_map { it["run"] }
    scripts.each { |script| assert_no_match(/\$\{\{/, script, "expressions reach the scripts only through the environment") }
    assert scripts.any? { it.include?('git -c gpg.ssh.allowedSignersFile=.github/allowed_signers tag -v "$TAG"') }
    assert scripts.any? { it.include?('git -c tar.umask=0002 archive --format=tar.gz --prefix="stopan-$VERSION/" -o "dist/stopan-$VERSION.tar.gz" "refs/tags/$TAG"') },
      "the release build must make the archive that bin/release compares with git archive of the tag"
    assert scripts.any? { it.include?("dist/stopan-$VERSION.tar.gz.intoto.jsonl") }
  end
end
