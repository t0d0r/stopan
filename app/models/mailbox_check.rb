require "net/imap"

# One check of an organization's IMAP mailbox (specs/organization-mail.md
# "Fetching"): unseen messages, oldest first, at most BATCH, each turned
# into a ticket or reply and marked seen, even when it fails.
class MailboxCheck
  BATCH = 50
  TIMEOUT = 30
  LOCKS = Concurrent::Map.new

  attr_reader :organization

  def initialize(organization, imap_class: Net::IMAP)
    @organization = organization
    @imap_class = imap_class
  end

  # Processes new mail and records the result on the organization.
  # Returns the number of messages taken in, or nil when another check of
  # this mailbox is running.
  def run
    lock = LOCKS.compute_if_absent(organization.id) { Mutex.new }
    return unless lock.try_lock

    begin
      count = 0
      error = nil
      connect do |imap|
        imap.select(organization.imap_folder)
        imap.uid_search([ "UNSEEN" ]).sort.first(BATCH).each do |uid|
          raw = imap.uid_fetch(uid, "BODY.PEEK[]")&.first&.attr&.fetch("BODY[]", nil)
          MailboxMessage.new(organization, raw).process
          count += 1
        rescue StandardError => e
          error = "#{e.class}: #{e.message}"
          Rails.logger.error("Mailbox of organization #{organization.id}: message #{uid} failed: #{error}")
        ensure
          imap.uid_store(uid, "+FLAGS", [ :Seen ])
        end
      end
      record(count, error)
      count
    rescue StandardError => e
      record(0, "#{e.class}: #{e.message}")
      0
    ensure
      lock.unlock
    end
  end

  # Logs in and counts unseen messages, for the admin's "Check the mailbox".
  def probe
    connect do |imap|
      imap.examine(organization.imap_folder)
      imap.uid_search([ "UNSEEN" ]).size
    end
  end

  private

  def connect
    ssl = organization.imap_ssl? ? { verify_mode: OpenSSL::SSL::VERIFY_PEER } : false
    imap = @imap_class.new(organization.imap_address, port: organization.imap_port, ssl: ssl, open_timeout: TIMEOUT)
    imap.starttls(verify_mode: OpenSSL::SSL::VERIFY_PEER) if !ssl && imap.capable?("STARTTLS")
    if organization.google_mail?
      connection = organization.mail_connection or raise GoogleOauth::Error, "no Google account connected"
      imap.authenticate("XOAUTH2", connection.email, connection.access_token)
    else
      imap.login(organization.imap_username, organization.imap_password.to_s)
    end
    yield imap
  ensure
    begin
      imap&.logout
    rescue StandardError
      nil
    end
    imap&.disconnect unless imap.nil? || imap.disconnected?
  end

  def record(count, error)
    organization.update_columns(imap_last_checked_at: Time.current, imap_last_error: error&.first(500),
                                imap_messages_count: organization.imap_messages_count + count)
    RefreshesAdminPages.broadcast
  end
end
