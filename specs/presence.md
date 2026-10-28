# Who is online now

Operator, 2026-10-28: "show at top how many users are connected and use
the system (like Google document share)". Staff see, live, who has Stopan
open: in the menu bar for the whole system, and on a ticket page who else
has that ticket open, so two agents do not answer the same ticket at once.

## What is shown

### Menu bar (staff only)

- A presence button between the search and the notification bell: a green
  dot, up to three avatars (initials on the user's paper colour, as in
  the queue) of the staff online, and the number of people online, the
  reader included. Its accessible name says "5 people online now".
- The button opens a panel (a `details` dropdown like the notification
  panel; closes on a click outside or Escape): "Online now", the staff
  online one per row (avatar, name, role icon; the reader marked "you"),
  then one line with the number of requesters online ("and 2
  requesters"), never their names.
- Requesters counted for an agent are those who share an organization
  with the agent (the agent's ticket scope, roles.md); administrators
  count all requesters. Staff names are visible to all staff, as in the
  assignee menus.
- Requesters do not see the button. They are counted, nothing more.
- On phones the button stays in the one-row bar (icon, search, presence,
  bell, menu button) and shows the dot and the number only; the panel
  spans the screen like the notification panel.

### Ticket page (staff only)

- At the top of the timeline column (above "Activity"; outside the
  request note, whose text is swapped for the edit form): "Also viewing
  now:" and the avatars and names of the other people who have this ticket open now,
  staff and the requester (with "requester" after the name). The reader
  is never listed. With nobody else the line is not shown.
- Only people who may see the ticket are ever counted on it (the
  subscription checks `Ticket.visible_to`).

## How it works

- **Online means a signed-in page is open.** Every page of a signed-in
  user with an organization subscribes to `PresenceChannel` (Action
  Cable, the connection that already carries the live signals), with the
  ticket number as a parameter on a ticket page. Each subscription is one
  open page: `subscribed` adds it, `unsubscribed` (page left, tab closed,
  connection lost) removes it. A user is online while at least one of
  their pages is open.
- **In process memory**, like the share viewer count (sharing.md "Who is
  viewing now"): `Presence` keeps a `Concurrent::Map` of open pages
  (user, ticket). One Puma process with the async cable adapter, so pages
  and requests see the same map; a restart starts empty and open pages
  count again as they reconnect.
- **Signal, then fetch.** After a change `Presence` waits one second,
  compares the set of (user, ticket) pairs with the last one it
  announced, and only when it differs broadcasts
  `<turbo-stream action="presence_refresh">` to the staff presence
  stream `[:presence, :staff]`. The signal carries no names. Each staff
  page then fetches `GET /presence` (with `?ticket=<number>` on a ticket
  page) as a Turbo Stream that updates the button, the panel and the
  viewers line, rendered for that reader: their language, their scope,
  without themselves. A Turbo page refresh or a visit drops and adds the
  page's subscription within the second, so it causes no signal.
- Requesters subscribe to their own stream `[user, :presence]`, which
  nothing is sent to; the channel accepts only the reader's own stream.
- `GET /presence` is for staff only (403 for requesters); the ticket
  parameter is looked up through `Ticket.visible_to`, an unknown or
  hidden ticket gives no viewers line.
- The page renders the current state on load, the reader included, so
  it is right before the first signal.
- An open presence panel is updated in place (only its list changes).

## Not in this phase

Last seen times, what page each person is on, typing indicators, names
of viewers on shared pages (sharing.md keeps a count only), several
processes (would need solid_cable or Redis and a shared store).

## Acceptance

`test/models/presence_test.rb` (join and leave, a user online while one
page is open, viewers per ticket, a signal only when the set changes),
`test/channels/presence_channel_test.rb` (own stream only, the ticket only
when visible, leaving on unsubscribe) and
`test/controllers/presence_controller_test.rb` (staff only, the reader not
listed, requesters as a count within the agent's organizations, the
viewers line).

## Security Note

Presence tells staff who is using the system now; it is shown only to
staff, never to requesters or on shared pages. The broadcast is a bare
signal; names come over HTTP with the usual sign-in, role and
`visible_to` checks, so an agent never learns about requesters or
tickets outside their organizations. Anyone with several tabs open counts
once per user, and the data lives only in memory.
