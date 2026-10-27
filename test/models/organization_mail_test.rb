require "test_helper"

# Mail settings of an organization (specs/organization-mail.md "Settings").
class OrganizationMailTest < ActiveSupport::TestCase
  def smtp(**attributes)
    organizations(:acme).reload.tap do |org|
      org.assign_attributes(smtp_enabled: true, smtp_address: "smtp.acme.example", smtp_username: "desk",
                            smtp_password: "s3cret-pass", mail_from: "Acme Support <support@acme.example>", **attributes)
    end
  end

  test "enabled parts need their server and addresses" do
    org = organizations(:acme)
    org.assign_attributes(smtp_enabled: true, imap_enabled: true)
    assert_not org.valid?
    assert_includes org.errors.attribute_names, :smtp_address
    assert_includes org.errors.attribute_names, :mail_from
    assert_includes org.errors.attribute_names, :imap_address
    assert_includes org.errors.attribute_names, :mailbox_address

    assert smtp.valid?
    assert_not smtp(mail_from: "not an address").valid?
    assert_not smtp(smtp_port: 70_000).valid?
  end

  test "servers inside the network are refused" do
    %w[127.0.0.1 10.1.2.3 192.168.0.5 169.254.1.1 ::1 [::1] localhost mail.localhost 0.0.0.0].each do |host|
      org = smtp(smtp_address: host)
      assert_not org.valid?, host
      assert_includes org.errors[:smtp_address], "must be a public mail server, not an address inside the network"
    end
    assert smtp(smtp_address: "203.0.113.10").valid?
  end

  test "passwords are stored encrypted and can be removed" do
    org = smtp
    org.save!
    raw = Organization.connection.select_value("SELECT smtp_password FROM organizations WHERE id = #{org.id}")
    assert_not_includes raw, "s3cret-pass"
    assert_equal "s3cret-pass", Organization.find(org.id).smtp_password

    org.update!(remove_smtp_password: "1")
    assert_nil org.reload.smtp_password
  end

  test "SMTP settings set every key from the organization" do
    settings = smtp(smtp_security: "tls").smtp_settings
    assert_equal "smtp.acme.example", settings[:address]
    assert_equal "acme.example", settings[:domain]
    assert_equal :plain, settings[:authentication]
    assert settings[:tls]
    assert_not settings[:enable_starttls]
    assert settings.key?(:user_name)
    assert_equal "support@acme.example", smtp.mail_from_address
  end
end
