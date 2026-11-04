require "test_helper"

load Rails.root.join("bin/release-notes").to_s

# Release notes from Conventional Commits (specs/release.md "Release notes").
class ReleaseNotesTest < ActiveSupport::TestCase
  def notes(subjects, since: nil, version: nil)
    commits = subjects.each_with_index.map do |(subject, body), index|
      ReleaseNotes::Commit.new(format("%07x", index + 1), subject, body.to_s)
    end
    ReleaseNotes.new(commits, since: since, version: version).to_markdown
  end

  def sections(markdown)
    markdown.scan(/^## (.+)$/).flatten
  end

  test "commits are grouped by type in a fixed order, oldest first, empty sections left out" do
    markdown = notes([
      "docs(specs): describe releases",
      "feat(ui): stopan wordmark in the menu bar",
      "fix(ui): keep the caret on click",
      "chore(deps): update gems with known security fixes",
      "refactor: split the helper",
      "feat(mail): read replies"
    ])
    assert_equal [ "Features", "Fixes", "Dependencies", "Documentation", "Other changes", "Security Note" ], sections(markdown)
    features = markdown[/## Features\n\n(.*?)\n\n/m, 1].lines.map(&:chomp)
    assert_equal [ "- **ui:** stopan wordmark in the menu bar (0000002)", "- **mail:** read replies (0000006)" ], features
    assert_includes markdown, "- split the helper (0000005)"
  end

  test "breaking changes come first, from the bang or the footer" do
    markdown = notes([
      "feat(api): add revisions",
      "feat(api)!: drop the v0 token header",
      [ "refactor(db): rename the column", "Explain.\n\nBREAKING CHANGE: the column is renamed" ]
    ])
    assert_equal [ "Breaking changes", "Features", "Security Note" ], sections(markdown)
    breaking = markdown[/## Breaking changes\n\n(.*?)\n\n/m, 1]
    assert_includes breaking, "drop the v0 token header (0000002)"
    assert_includes breaking, "rename the column (0000003)"
  end

  test "working notes and deploy records are left out, other docs stay" do
    markdown = notes([
      "docs(session): record the release",
      "docs(deploy): record the 6a89f1d production update",
      "docs(todo): mark items done",
      "docs(readme): show the badges"
    ])
    assert_equal [ "Documentation", "Security Note" ], sections(markdown)
    refute_match(/record the|mark items/, markdown)
    assert_includes markdown, "- **readme:** show the badges (0000004)"
  end

  test "any type with the deps scope is a dependency; other subjects fall into other changes" do
    markdown = notes([ "ci(deps): bump the actions group", "Merge branch 'x'", "wip(ui): something" ])
    assert_includes markdown[/## Dependencies\n\n(.*?)\n\n/m, 1], "bump the actions group"
    other = markdown[/## Other changes\n\n(.*?)\n\n/m, 1]
    assert_includes other, "- Merge branch 'x' (0000002)"
    assert_includes other, "- **ui:** something (0000003)"
  end

  test "mentions and issue numbers are quoted so GitHub neither notifies nor links" do
    markdown = notes([ "fix(mail): replies from @someone on #1009 were missing, see `#12`" ])
    assert_includes markdown, "replies from `@someone` on `#1009` were missing, see `#12`"
  end

  test "the first line names the previous tag, and the notes end with the security note" do
    assert_match(/\AFirst release: every change since the start of the project\.\n/, notes([ "feat: x" ]))
    markdown = notes([ "feat: x" ], since: "v0.1.0")
    assert_match(/\AChanges since v0\.1\.0\.\n/, markdown)
    assert_match(/## Security Note\n\nThe tag and the source archive .*Report vulnerabilities privately, as SECURITY\.md describes.*security fixes\.\n\z/m, markdown)
  end

  test "the security note shows how to verify the signed archive of this version" do
    markdown = notes([ "feat: x" ], version: "0.2.0")
    assert_includes markdown, "ssh-keygen -Y verify -f allowed_signers -I t0d0r -n file \\\n  -s stopan-0.2.0.tar.gz.sig < stopan-0.2.0.tar.gz\n"
    assert_not_includes markdown, "X.Y.Z"
    assert_includes notes([ "feat: x" ]), "stopan-X.Y.Z.tar.gz"
  end
end
