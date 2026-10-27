require "test_helper"

# Service desk settings (specs/board.md).
class Admin::SettingsControllerTest < ActionDispatch::IntegrationTest
  test "admins set the days; others may not" do
    sign_in users(:admin)
    get admin_settings_url
    assert_select "input[name='app_setting[auto_postpone_days]'][value='30']"
    patch admin_settings_url, params: { app_setting: { auto_postpone_days: 14 } }
    assert_redirected_to admin_settings_url
    assert_equal 14, AppSetting.current.auto_postpone_days
    patch admin_settings_url, params: { app_setting: { auto_postpone_days: -1 } }
    assert_response :unprocessable_content

    sign_in users(:agent)
    get admin_settings_url
    assert_redirected_to root_url
  end

  test "the panels sit in three fixed columns, not CSS columns (specs/ui.md \"Panel columns\")" do
    sign_in users(:admin)
    get admin_settings_url
    assert_select ".panel-columns > .panel-columns__column", 3
    assert_select ".panel-columns__column:nth-child(1) > section", 3
    assert_select ".panel-columns__column:nth-child(2) > #mailboxes + #translation"
    assert_select ".panel-columns__column:nth-child(3) > #google + #stages"
  end

  test "admins switch automatic mail fetching on and choose how often (specs/organization-mail.md)" do
    sign_in users(:admin)
    get admin_settings_url
    assert_select "#mailboxes input[type=checkbox][name='app_setting[mailbox_polling]']:not([checked])"
    assert_select "#mailboxes select[name='app_setting[mailbox_poll_seconds]'] option", 5
    assert_select "#mailboxes option[selected][value='120']", "Every 2 minutes"
    assert_select "#mailboxes option[value='60']", "Every minute"

    patch admin_settings_url, params: { app_setting: { mailbox_polling: "1", mailbox_poll_seconds: "300" } }
    assert_redirected_to admin_settings_url
    setting = AppSetting.current.reload
    assert setting.mailbox_polling?
    assert_equal 300, setting.mailbox_poll_seconds

    patch admin_settings_url, params: { app_setting: { mailbox_poll_seconds: "7" } }
    assert_response :unprocessable_content
    assert_select "#mailboxes .form-errors"
    assert_equal 300, AppSetting.current.reload.mailbox_poll_seconds
  end

  test "cards due soon show the stamp and staff see the note" do
    AppSetting.current.update!(auto_postpone_days: 30)
    tickets(:printer).update_columns(updated_at: 27.days.ago)
    sign_in users(:agent)
    get board_url
    assert_select "#card_ticket_#{tickets(:printer).id} .postpone-stamp .postpone-stamp__number", "3"
    assert_select "#card_ticket_#{tickets(:email_account).id} .postpone-stamp", 0
    get ticket_url(tickets(:printer))
    assert_select ".postpone-note", "Moves to Not now in 3 days without activity."
  end

  test "admins add, rename, reorder and delete stages" do
    sign_in users(:admin)
    post admin_stages_url, params: { stage: { status: "open", name: "Investigating", color: "pink" } }
    post admin_stages_url, params: { stage: { status: "open", name: "QA", color: "green" } }
    first, second = Stage.where(status: "open").ordered.to_a
    patch admin_stage_url(second), params: { stage: { name: "QA to confirm", color: "blue", status: "done" } }
    assert_equal [ "QA to confirm", "blue", "open" ], second.reload.slice(:name, :color, :status).values
    patch move_admin_stage_url(second, direction: "up")
    assert_equal [ second, first ], Stage.where(status: "open").ordered.to_a
    get admin_settings_url
    assert_select "#stages input[value='QA to confirm']"
    delete admin_stage_url(first)
    assert_not Stage.exists?(first.id)

    sign_in users(:agent)
    post admin_stages_url, params: { stage: { status: "open", name: "Sneaky", color: "pink" } }
    assert_not Stage.exists?(name: "Sneaky")
  end
end
