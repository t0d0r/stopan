# How many shared pages of each link are open right now (specs/sharing.md
# "Who is viewing now"). Kept in process memory, keyed by the token's
# digest: Action Cable runs in the web process with the async adapter, so
# requests and channels see the same counts.
module ShareViewers
  COUNTS = Concurrent::Map.new

  def self.count(ticket)
    ticket.shared? ? COUNTS.fetch(ticket.share_digest, 0) : 0
  end

  def self.join(ticket, digest)
    change(ticket, digest, 1)
  end

  def self.leave(ticket, digest)
    change(ticket, digest, -1)
  end

  # Tells the shared pages of the link and, while it is still the ticket's
  # link, the ticket pages. Only the number is sent.
  def self.change(ticket, digest, delta)
    count = 0
    COUNTS.compute(digest) do |value|
      count = [ value.to_i + delta, 0 ].max
      count unless count.zero?
    end
    streams = [ [ ticket, :share, digest ] ]
    streams += [ [ ticket, :page, :staff ], [ ticket, :page, :public ] ] if current_link?(ticket, digest)
    streams.each do |stream|
      Turbo::StreamsChannel.broadcast_action_to(*stream, action: "share_viewers", target: "share-viewers",
                                                         attributes: { count: count })
    end
  end

  def self.current_link?(ticket, digest)
    token = Ticket.where(id: ticket.id).pick(:share_token)
    token.present? && ticket.share_digest(token) == digest
  end
end
