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
      'gh run download "$run" --name release-archive',
      'gh run download "$run" --name release-provenance',
      'gh attestation verify "$archive" --bundle "$archive.intoto.jsonl" --repo "$repo"',
      '--signer-workflow "$repo/.github/workflows/$builder" --source-ref "$source_ref" --source-digest "$sha"',
      'gzip -dc "$archive" | cmp -s - <(git -c tar.umask=0002 archive --format=tar --prefix="stopan-$version/" "$tag")',
      'ssh-keygen -q -Y sign -f "$key" -n file "$archive"',
      'ssh-keygen -Y verify -f "$signers" -I "$principal" -n file'
    ]
    positions = checks.map { |check| files.index(check) }
    assert positions.all?, "release_files must wait, download, verify the provenance and the content, then sign"
    assert_equal positions.sort, positions
    assert_no_match(/--format=tar\.gz/, files, "the archive is built by the release build, not on this machine")
  end

  def workflow(name) = YAML.load_file(Rails.root.join(".github/workflows/#{name}"))
  def uses(steps) = steps.filter_map { it["uses"]&.split("@")&.first }
  def scripts(steps) = steps.filter_map { it["run"] }

  test "the release build starts on a release tag or by hand and only calls the reusable build" do
    release = workflow("release.yml")
    triggers = release[true] # YAML 1.1 reads the key "on" as true
    assert_equal [ "v[0-9]+.[0-9]+.[0-9]+" ], triggers.dig("push", "tags")
    assert_equal [ "tag" ], triggers.dig("workflow_dispatch", "inputs").keys
    assert_equal({}, release["permissions"])
    assert_equal [ "release-build" ], release["jobs"].keys
    call = release.dig("jobs", "release-build")
    assert_equal "./.github/workflows/release-build.yml", call["uses"]
    assert_equal [ "tag" ], call["with"].keys
    assert_equal({ "contents" => "read", "id-token" => "write", "attestations" => "write" }, call["permissions"])
    assert_nil call["steps"]
    assert_match(/^builder=release-build\.yml$/, read("bin/release"), "bin/release must require provenance signed by the reusable build")
  end

  test "the reusable build is SLSA Build Level 3: the build cannot sign, and the signing job runs no project code" do
    build_workflow = workflow("release-build.yml")
    assert_equal [ "tag" ], build_workflow[true].dig("workflow_call", "inputs").keys
    assert_equal({}, build_workflow["permissions"])
    assert_equal %w[build provenance], build_workflow["jobs"].keys

    build = build_workflow.dig("jobs", "build")
    assert_equal({ "contents" => "read" }, build["permissions"], "the build job must not get the OIDC token")
    assert_equal %w[actions/checkout actions/upload-artifact], uses(build["steps"])
    assert_equal false, build["steps"].find { it["uses"]&.start_with?("actions/checkout@") }.dig("with", "persist-credentials")
    assert_equal "release-archive", build["steps"].find { it["uses"]&.start_with?("actions/upload-artifact@") }.dig("with", "name")
    assert scripts(build["steps"]).any? { it.include?('git -c gpg.ssh.allowedSignersFile=.github/allowed_signers tag -v "$TAG"') }
    assert scripts(build["steps"]).any? { it.include?('git -c tar.umask=0002 archive --format=tar.gz --prefix="stopan-$VERSION/" -o "dist/stopan-$VERSION.tar.gz" "refs/tags/$TAG"') },
      "the release build must make the archive that bin/release compares with git archive of the tag"

    provenance = build_workflow.dig("jobs", "provenance")
    assert_equal "build", provenance["needs"]
    assert_equal({ "id-token" => "write", "attestations" => "write" }, provenance["permissions"])
    assert_equal %w[actions/attest-build-provenance actions/upload-artifact], uses(provenance["steps"]), "the signing job checks nothing out"
    assert_equal "release-provenance", provenance["steps"].find { it["uses"]&.start_with?("actions/upload-artifact@") }.dig("with", "name")
    assert scripts(provenance["steps"]).any? { it.include?("[[ $SHA256 =~ ^[0-9a-f]{64}$ ]]") }, "the digest from the build job must be checked"
    assert scripts(provenance["steps"]).any? { it.include?('"provenance/$ARCHIVE.intoto.jsonl"') }

    (build["steps"] + provenance["steps"]).filter_map { it["run"] }.each do |script|
      assert_no_match(/\$\{\{/, script, "expressions reach the scripts only through the environment")
    end
  end
end
