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

namespace :stopan do
  desc "Mark pending tickets without activity for the set number of days done (specs/board.md)"
  task close_pending: :environment do
    puts "#{AutoDone.run} ticket(s) marked done"
  end

  desc "Postpone tickets without activity for the set number of days (specs/board.md)"
  task postpone_inactive: :environment do
    puts "#{AutoPostpone.run} ticket(s) moved to Not now"
  end
end
