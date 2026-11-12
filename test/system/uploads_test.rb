require "application_system_test_case"

# The file drop zone in a browser (specs/ui.md "Form fields").
class UploadsTest < ApplicationSystemTestCase
  def file(name) = Rails.root.join("test/fixtures/files", name).to_s

  def drop(selector, name, content)
    page.execute_script(<<~JS, selector, name, content)
      const transfer = new DataTransfer();
      transfer.items.add(new File([arguments[2]], arguments[1], { type: "text/plain" }));
      const zone = document.querySelector(arguments[0]);
      ["dragenter", "dragover", "drop"].forEach((type) =>
        zone.dispatchEvent(new DragEvent(type, { bubbles: true, cancelable: true, dataTransfer: transfer })));
    JS
  end

  test "picked and dropped files add up, one is removed, the rest go with the reply" do
    ticket = tickets(:printer)
    sign_in_as users(:agent)
    visit ticket_path(ticket)

    within("#composer") do
      assert_selector "[data-dropzone-area]"
      assert_no_selector ".dropzone__file"
      attach_file "comment_files", file("hello.txt"), make_visible: true
      assert_selector ".dropzone__file", count: 1
      attach_file "comment_files", file("dot.png"), make_visible: true
      assert_selector ".dropzone__file", count: 2
    end
    drop "#composer [data-dropzone]", "dropped.txt", "dropped in a browser"
    within("#composer") do
      assert_selector ".dropzone__file", count: 3
      assert_selector ".dropzone__name", text: "dropped.txt"
      find(".dropzone__file", text: "dot.png").find(".dropzone__remove").click
      assert_selector ".dropzone__file", count: 2
      fill_in "comment_body", with: "Two files attached."
      find("[data-composer-submit]").click
    end

    assert_selector ".timeline .message", text: "Two files attached."
    comment = ticket.comments.order(:id).last
    assert_equal %w[dropped.txt hello.txt], comment.files.map { |f| f.filename.to_s }.sort
    assert_equal "dropped in a browser", comment.files.find { |f| f.filename.to_s == "dropped.txt" }.download
  end

  test "a file over the size limit is left out and named" do
    sign_in_as users(:agent)
    visit ticket_path(tickets(:printer))
    page.execute_script(<<~JS, Attachable::MAX_SIZE + 1)
      const transfer = new DataTransfer();
      transfer.items.add(new File([new Uint8Array(arguments[0])], "big.bin"));
      const zone = document.querySelector("#composer [data-dropzone]");
      ["dragenter", "dragover", "drop"].forEach((type) =>
        zone.dispatchEvent(new DragEvent(type, { bubbles: true, cancelable: true, dataTransfer: transfer })));
    JS
    within("#composer") do
      assert_selector "[data-dropzone-errors] .field-error", text: "big.bin"
      assert_no_selector ".dropzone__file"
    end
  end
end
