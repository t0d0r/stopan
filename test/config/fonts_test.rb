require "test_helper"

# The Omarchy theme's bundled faces (specs/ui.md "Themes").
class FontsConfigTest < ActiveSupport::TestCase
  FACES = %w[Geist-Variable JetBrainsMono-Regular JetBrainsMono-Medium JetBrainsMono-SemiBold JetBrainsMono-Bold].freeze

  test "the stylesheet points at every bundled face by its digested path, from this site only" do
    assets = Rails.application.assets.load_path
    css = assets.find("application.css").compiled_content
    FACES.each do |face|
      font = assets.find("#{face}.woff2")
      assert font, "app/assets/fonts/#{face}.woff2 is missing"
      assert_equal "wOF2", font.content[0, 4], "#{face} is not a WOFF2 file"
      assert_includes css, %(url("/assets/#{font.digested_path}") format("woff2"))
    end
    assert_no_match %r{url\(["']?(?:https?:)?//[^)]*\.woff2}, css
    assert_equal FACES.sort, Dir[Rails.root.join("app/assets/fonts/*")].map { File.basename(it, ".woff2") }.sort
  end

  test "each family keeps its SIL Open Font License text" do
    { "geist/LICENSE.txt" => "Vercel", "jetbrains-mono/OFL.txt" => "JetBrains Mono" }.each do |path, holder|
      text = Rails.root.join("vendor/fonts", path).read
      assert_includes text, holder
      assert_includes text, "SIL OPEN FONT LICENSE Version 1.1"
    end
  end
end
