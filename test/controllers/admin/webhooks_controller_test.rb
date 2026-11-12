require "test_helper"

# specs/webhooks.md "Who manages them"
class Admin::WebhooksControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup { @organization = organizations(:acme) }

  def add(url: "https://hooks.example.com/stopan", events: Webhook::EVENTS)
    post admin_organization_webhooks_url(@organization), params: { webhook: { url: url, events: events } }
  end

  test "a super administrator adds a webhook and sees its secret once" do
    sign_in users(:admin)
    get admin_organization_url(@organization)
    assert_select "#webhooks form input[type=url][name='webhook[url]']"
    assert_select "#webhooks input[type=checkbox][name='webhook[events][]'][checked]", 2
    assert_select "#webhooks .panel__empty", "No webhook yet."

    assert_difference("Webhook.count", 1) { add }
    webhook = Webhook.last
    assert_redirected_to admin_organization_url(@organization, anchor: "webhooks")
    follow_redirect!
    assert_select "#new-webhook-secret[value=?]", webhook.secret
    assert_select "##{ActionView::RecordIdentifier.dom_id(webhook)} .webhooks__url", "https://hooks.example.com/stopan"
    assert_select "##{ActionView::RecordIdentifier.dom_id(webhook)} .share-list__meta", /new tickets and public replies.*on.*never sent/m

    get admin_organization_url(@organization)
    assert_select "#new-webhook-secret", 0
    assert_not_includes response.body, webhook.secret
  end

  test "a refused URL adds nothing and says why" do
    sign_in users(:admin)
    assert_no_difference("Webhook.count") { add(url: "http://hooks.example.com/") }
    assert_match "must start with https://", flash[:alert]
    assert_no_difference("Webhook.count") { add(events: []) }
  end

  test "test, switch off and on, delete" do
    sign_in users(:admin)
    add
    webhook = Webhook.last

    assert_enqueued_jobs(1, only: WebhookDeliveryJob) { post ping_admin_webhook_url(webhook) }
    webhook.update_columns(failures: 7, last_error: "timeout", last_sent_at: Time.current)
    get admin_organization_url(@organization)
    assert_select "##{ActionView::RecordIdentifier.dom_id(webhook)} .share-list__meta", /failed: timeout, 7 in a row/

    patch admin_webhook_url(webhook), params: { webhook: { active: "0" } }
    assert_not webhook.reload.active?
    assert_no_enqueued_jobs(only: WebhookDeliveryJob) { post ping_admin_webhook_url(webhook) }
    get admin_organization_url(@organization)
    assert_select "##{ActionView::RecordIdentifier.dom_id(webhook)} .share-list__meta", /switched off/

    patch admin_webhook_url(webhook), params: { webhook: { active: "1" } }
    assert webhook.reload.active?
    assert_equal 0, webhook.failures

    assert_difference("Webhook.count", -1) { delete admin_webhook_url(webhook) }
  end

  test "organization administrators, agents and requesters cannot manage or see webhooks" do
    webhook = @organization.webhooks.create!(url: "https://hooks.example.com/x", event_names: Webhook::EVENTS)
    Membership.find_by!(user: users(:agent), organization: @organization).update!(admin: true)
    sign_in users(:agent)
    get admin_organization_url(@organization)
    assert_response :success
    assert_select "#webhooks", 0

    assert_no_difference("Webhook.count") do
      add
      delete admin_webhook_url(webhook)
    end
    patch admin_webhook_url(webhook), params: { webhook: { active: "0" } }
    assert webhook.reload.active?
    assert_no_enqueued_jobs(only: WebhookDeliveryJob) { post ping_admin_webhook_url(webhook) }

    sign_in users(:anna)
    assert_no_difference("Webhook.count") { add }
  end
end
