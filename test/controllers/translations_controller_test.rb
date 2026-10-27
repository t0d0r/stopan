require "test_helper"

# The "Translate" button on messages (specs/translation.md), with a fake
# DeepL client.
class TranslationsControllerTest < ActionDispatch::IntegrationTest
  class FakeClient
    attr_reader :calls
    attr_accessor :source, :error

    def initialize
      @calls = []
      @source = "bg"
    end

    def translate(text, target:)
      raise error if error

      calls << [ text, target.to_s ]
      [ "Translated: #{text}", source ]
    end
  end

  setup do
    @env_key = ENV.delete("DEEPL_API_KEY")
    AppSetting.current.update!(deepl_api_key: "test-key", translation_enabled: true)
    Translation.client = @client = FakeClient.new
    TranslationsController::RATE_LIMIT_STORE.clear
    @ticket = tickets(:printer)
    @reply = @ticket.add_comment(author: users(:anna), body: "Принтерът пак печата празно.")
  end

  teardown do
    ENV["DEEPL_API_KEY"] = @env_key
    Translation.client = nil
  end

  def translate(message, ticket: @ticket)
    post ticket_translations_url(ticket), params: { message: message }
  end

  test "staff see Translate under the request and every message; requesters and shared pages never" do
    sign_in users(:agent)
    get ticket_url(@ticket)
    assert_select "#description form.translation__form[action=?] input[name=message][value=description]", ticket_translations_path(@ticket)
    assert_select "#event-#{@reply.event.id} form.translation__form input[name=message][value=?]", "comment-#{@reply.id}"
    assert_select "form.translation__form", 1 + @ticket.comments.count

    sign_in users(:anna)
    get ticket_url(@ticket)
    assert_select "form.translation__form", 0
    translate "description"
    assert_response :forbidden

    @ticket.share!(actor: users(:agent), password: nil)
    sign_in users(:agent)
    get shared_ticket_url(@ticket.share_token)
    assert_select "form.translation__form", 0
  end

  test "nothing is offered when switched off or without a key" do
    sign_in users(:agent)
    AppSetting.current.update!(translation_enabled: false)
    get ticket_url(@ticket)
    assert_select "form.translation__form", 0
    translate "description"
    assert_response :forbidden

    # No stored key and none in the environment (as if removed directly).
    AppSetting.current.update_columns(translation_enabled: true, deepl_api_key: nil)
    get ticket_url(@ticket)
    assert_select "form.translation__form", 0
    assert_empty @client.calls

    ENV["DEEPL_API_KEY"] = "env-key"
    get ticket_url(@ticket)
    assert_select "form.translation__form", 1 + @ticket.comments.count
  end

  test "a translation is stored, shown under its message and reused until the text changes" do
    sign_in users(:agent)
    assert_difference "Translation.count", 1 do
      translate "comment-#{@reply.id}"
    end
    assert_redirected_to ticket_url(@ticket, anchor: "event-#{@reply.event.id}")
    assert_equal [ [ "Принтерът пак печата празно.", "en" ] ], @client.calls

    get ticket_url(@ticket)
    assert_select "#event-#{@reply.event.id} .translation" do
      assert_select ".translation__note", "Machine translation (DeepL), original: Bulgarian"
      assert_select ".ticket-text[lang=en]", /Translated: Принтерът пак печата празно\./
      assert_select "button.translation__hide[hidden]", "Hide"
    end
    assert_select "#event-#{@reply.event.id} form.translation__form", 0
    assert_select "#description form.translation__form"

    # Another agent reads the stored one; DeepL is not asked again.
    sign_in users(:admin)
    get ticket_url(@ticket)
    assert_select "#event-#{@reply.event.id} .translation"
    assert_equal 1, @client.calls.size

    @reply.edit(editor: users(:anna), body: "Сега печата наполовина.")
    get ticket_url(@ticket)
    assert_select "#event-#{@reply.event.id} .translation", 0
    assert_select "#event-#{@reply.event.id} form.translation__form"
    assert_no_difference "Translation.count" do
      translate "comment-#{@reply.id}"
    end
    assert_equal "Translated: Сега печата наполовина.", @reply.translations.sole.text
  end

  test "the target is the viewer's language; text already in it says so" do
    sign_in users(:agent)
    @client.source = "en"
    translate "description"
    get ticket_url(@ticket)
    assert_select "#description .translation .translation__note", "This message is already in English."

    users(:agent).update!(language: "de")
    @client.source = "en"
    translate "description"
    assert_equal "de", @client.calls.last.last
    get ticket_url(@ticket)
    assert_select "#description .translation .translation__note", "Maschinelle Übersetzung (DeepL), Original: Englisch"
    assert_equal 2, @ticket.translations.count
  end

  test "Markdown messages are translated through the same sanitized rendering" do
    Comment.where(id: @reply.id).update_all(markdown: true, body: "**wichtig** <script>alert(1)</script>")
    sign_in users(:agent)
    translate "comment-#{@reply.id}"
    get ticket_url(@ticket)
    assert_select "#event-#{@reply.event.id} .translation .markdown-body strong", "wichtig"
    assert_select "#event-#{@reply.event.id} .translation script", 0
  end

  test "failures and long messages store nothing and say so" do
    sign_in users(:agent)
    @client.error = DeeplClient::Error.new("DeepL answered 456")
    assert_no_difference "Translation.count" do
      translate "description"
    end
    follow_redirect!
    assert_select ".flash", /The translation did not work/

    @client.error = nil
    @ticket.update_columns(description: "x" * (Translation::MAX_LENGTH + 1))
    assert_no_difference "Translation.count" do
      translate "description"
    end
    follow_redirect!
    assert_select ".flash", /too long to translate/
    assert_empty @client.calls
  end

  test "only messages of this ticket, and a rate limit per user" do
    sign_in users(:agent)
    other = tickets(:vpn).add_comment(author: users(:agent), body: "Elsewhere.")
    translate "comment-#{other.id}"
    assert_response :not_found
    # A 404 from an exception keeps no session cookie in integration tests.
    sign_in users(:agent)
    translate "everything"
    assert_response :not_found

    sign_in users(:agent)
    30.times { translate "description" }
    translate "description"
    follow_redirect!
    assert_select ".flash", /Too many translations/
  end

  test "administrators enter the key and switch it on in the settings; the key is write-only and encrypted" do
    sign_in users(:admin)
    AppSetting.current.update!(translation_enabled: false, deepl_api_key: nil)
    get admin_settings_url
    assert_select "#translation input[type=password][name='app_setting[deepl_api_key]']"
    assert_select "#translation", /No key stored/

    # Switching on without a key is refused.
    patch admin_settings_url, params: { app_setting: { translation_enabled: "1", deepl_api_key: "" } }
    assert_response :unprocessable_content
    assert_select "#translation .form-errors", /DeepL API key is needed before translation can be switched on/
    assert_not AppSetting.current.reload.translation_enabled?

    patch admin_settings_url, params: { app_setting: { translation_enabled: "1", deepl_api_key: " new-secret:fx " } }
    assert_redirected_to admin_settings_url
    setting = AppSetting.current.reload
    assert setting.translation_enabled?
    assert_equal "new-secret:fx", setting.deepl_api_key
    raw = AppSetting.connection.select_value("SELECT deepl_api_key FROM app_settings WHERE id = #{setting.id}")
    assert_no_match(/new-secret/, raw, "stored encrypted")

    get admin_settings_url
    assert_select "#translation", /A key is stored/
    assert_select "#translation input[name='app_setting[deepl_api_key]']:not([value])"
    assert_no_match(/new-secret/, response.body)

    # A blank field keeps it; the check box removes it (and translation then needs a new key).
    patch admin_settings_url, params: { app_setting: { deepl_api_key: "", translation_enabled: "1" } }
    assert_equal "new-secret:fx", AppSetting.current.reload.deepl_api_key
    patch admin_settings_url, params: { app_setting: { remove_deepl_api_key: "1", translation_enabled: "0" } }
    assert_nil AppSetting.current.reload.deepl_api_key
  end

  test "the client uses the stored key" do
    AppSetting.current.update!(deepl_api_key: "stored:fx")
    assert_equal "https://api-free.deepl.com", DeeplClient.new.base_url
  end
end
