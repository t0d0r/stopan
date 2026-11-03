require "test_helper"

# Icons (specs/ui.md "Icons").
class IconsHelperTest < ActionView::TestCase
  test "every icon is inline SVG on the 24 px grid with only drawing elements" do
    IconsHelper::ICONS.each_key do |name|
      svg = Nokogiri::HTML5.fragment(icon(name)).at_css("svg")
      assert_equal "0 0 24 24", svg["viewBox"], name
      assert_equal "true", svg["aria-hidden"], name
      shapes = svg.css("path, rect, circle, g")
      assert shapes.any?, "#{name} draws nothing"
      assert_empty svg.css("script, foreignObject, image, use, a, style"), name
      shapes.each { |shape| assert_nil shape.attribute_nodes.find { |a| a.name.start_with?("on") || a.name.include?("href") }, name }
    end
  end

  test "small icons get a wider stroke; a label makes the icon an image" do
    assert_equal "2", Nokogiri::HTML5.fragment(icon(:link, size: 14)).at_css("svg")["stroke-width"]
    assert_equal "1.5", Nokogiri::HTML5.fragment(icon(:link, size: 18)).at_css("svg")["stroke-width"]
    svg = Nokogiri::HTML5.fragment(icon(:trash, label: "Delete")).at_css("svg")
    assert_equal [ "img", "Delete", nil ], [ svg["role"], svg["aria-label"], svg["aria-hidden"] ]
  end

  test "own drawings are scaled to the grid; the Heroicons licence ships with the code" do
    %i[markdown headset].each do |name|
      assert_equal "scale(1.5)", Nokogiri::HTML5.fragment(icon(name)).at_css("svg > g")["transform"]
    end
    license = Rails.root.join("vendor/heroicons/LICENSE").read
    assert_includes license, "MIT License"
    assert_includes license, "Tailwind Labs"
  end
end
