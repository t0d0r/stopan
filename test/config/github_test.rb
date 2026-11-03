require "test_helper"

# GitHub configuration (specs/ci.md): Dependabot updates and pinned actions.
class GithubConfigTest < ActiveSupport::TestCase
  def yaml(path) = YAML.load_file(Rails.root.join(path))

  test "Dependabot updates the actions and the gems, weekly, after a cooldown" do
    updates = yaml(".github/dependabot.yml").fetch("updates").index_by { |u| u["package-ecosystem"] }
    assert_equal %w[bundler github-actions], updates.keys.sort
    updates.each_value do |update|
      assert_equal [ "/", "weekly" ], [ update["directory"], update.dig("schedule", "interval") ]
      assert_operator update.dig("cooldown", "default-days"), :>=, 3
      assert update.dig("commit-message", "prefix").match?(/\A[a-z]+\(deps\)\z/)
    end
    assert_equal %w[minor patch], updates["bundler"].dig("groups", "gems", "update-types")
  end

  test "every workflow step pins its action to a full commit SHA" do
    Dir[Rails.root.join(".github/workflows/*.yml")].each do |file|
      File.read(file).scan(/^\s*(?:-\s*)?uses:\s*(\S+)/).flatten.each do |action|
        assert_match(/@\h{40}\z/, action, "#{File.basename(file)}: #{action} is not pinned to a commit SHA")
      end
    end
  end
end
