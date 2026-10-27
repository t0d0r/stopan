namespace :stopan do
  namespace :mailboxes do
    desc "Check every enabled organization mailbox once (specs/organization-mail.md)"
    task check: :environment do
      Organization.where(imap_enabled: true).find_each do |organization|
        count = MailboxCheck.new(organization).run
        puts "#{organization.name}: #{count.inspect} message(s); #{organization.reload.imap_last_error || "no error"}"
      end
    end
  end
end
