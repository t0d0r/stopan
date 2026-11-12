# Clears share links whose time ran out (specs/sharing.md "Expiry"). The
# links stop working at their time by themselves; this tidies up, records
# it in the timeline and closes pages that are still open. Run hourly
# with AutoPostpone and by bin/rails stopan:close_pending.
module ShareExpiry
  # Returns how many links were cleared.
  def self.run
    Ticket.share_expired.find_each.count(&:expire_share!)
  end
end
