require "test_helper"

# Markup behind the shared field style (specs/ui.md "Form fields"): the
# file drop zone keeps a real file input, joined field groups, leading
# icons, and each field's own error message. The look itself is checked
# in a browser.
class FormFieldsTest < ActionDispatch::IntegrationTest
  def assert_drop_zone(name:, id:, hint_id:)
    assert_select "[data-dropzone]" do
      assert_select "input[type=file][multiple][name=?][id=?][data-dropzone-input][aria-describedby=?]", name, id, hint_id
      assert_select "label.dropzone__area[for=?][hidden]", id do
        assert_select "svg.icon"
        assert_select ".dropzone__choose", "choose files"
      end
      assert_select "ul.dropzone__list[hidden][aria-label=?]", "Chosen files"
      assert_select "[data-dropzone-status][aria-live=polite]"
      assert_select "template[data-dropzone-item]"
    end
    assert_select "[data-dropzone][data-remove-label=?]", "Remove %{name}"
    assert_select "[data-dropzone][data-chosen-other=?]", "%{count} files chosen"
    assert_select "##{hint_id}.field-hint", /Up to 5 files, 10 MB each/
    assert_select "label[for=?]", id, minimum: 2
  end

  test "the new ticket form has a drop zone around a real file input" do
    sign_in users(:anna)
    get new_ticket_url
    assert_drop_zone name: "ticket[files][]", id: "ticket_files", hint_id: "files-hint"
    assert_select "label[for=ticket_files]:not(.dropzone__area)", "Attachments"
  end

  test "the composer has a drop zone around a real file input" do
    sign_in users(:agent)
    get ticket_url(tickets(:printer))
    assert_select "#composer" do
      assert_drop_zone name: "comment[files][]", id: "comment_files", hint_id: "composer-files-hint"
    end
  end

  test "the drop zone is translated" do
    sign_in users(:anna)
    get new_ticket_url, headers: { "Accept-Language" => "de" }
    assert_select ".dropzone__choose", "wählen Sie Dateien aus"
    assert_select "[data-dropzone][data-remove-label=?]", "%{name} entfernen"
  end

  test "the Cc email and the colleague select are joined to their Add buttons" do
    sign_in users(:agent)
    get ticket_url(tickets(:printer))
    assert_select "#followers form.followers__add.input-group" do
      assert_select "> .input-icon > svg.icon"
      assert_select "> .input-icon > input#cc_email.field-input[type=email][required]"
      assert_select "> button.btn[type=submit]", /Add/
    end
    assert_select "#followers form.followers__add.input-group > select#follower_user_id.select", maximum: 1
    assert_select "#followers .input-icon input[type=password]", 0
  end

  test "the share link and Copy link are joined top to bottom" do
    ticket = tickets(:printer)
    ticket.share!(actor: users(:agent), password: nil)
    sign_in users(:agent)
    get ticket_url(ticket)
    assert_select "#sharing .sharing__link.input-group.input-group--stacked" do
      assert_select "> .input-icon > svg.icon"
      assert_select "> .input-icon > input#share-url.field-input[readonly]"
      assert_select "> button.btn[data-copy=share-url]", /Copy link/
    end
  end

  test "search fields have a leading icon" do
    sign_in users(:agent)
    get search_url(q: "printer")
    assert_select ".search-page__query .input-icon > input#q.field-input[type=search]"
    sign_in users(:admin)
    get admin_users_url
    assert_select ".filters__search.input-icon > svg.icon"
    assert_select ".filters__search.input-icon > input#q.field-input[type=search]"
  end

  test "a field with an error shows its message under it, linked to the field" do
    sign_in users(:anna)
    post tickets_url, params: { ticket: { subject: "", description: "" } }
    assert_response :unprocessable_content
    assert_select ".form-errors[role=alert] li", 2
    assert_select "#ticket_subject[aria-invalid=true][aria-describedby='subject-hint ticket_subject_error']"
    assert_select "span.field-error#ticket_subject_error", "Subject can't be blank"
    assert_select "#ticket_description[aria-invalid=true][aria-describedby='description-hint ticket_description_error']"
    assert_select "span.field-error#ticket_description_error", "Description can't be blank"
    assert_select "#ticket_subject[aria-invalid=false]", 0
  end

  test "an association's error shows under its select" do
    sign_in users(:agent)
    post tickets_url, params: { ticket: { subject: "x", description: "y" } }
    assert_select "#ticket_requester_id[aria-invalid=true][aria-describedby~=ticket_requester_id_error]"
    assert_select "span.field-error#ticket_requester_id_error", /Requester/
  end

  test "fields without errors get no message" do
    sign_in users(:anna)
    get new_ticket_url
    assert_select ".field-error", 0
    assert_select "#ticket_subject[aria-describedby=subject-hint]"
  end
end
