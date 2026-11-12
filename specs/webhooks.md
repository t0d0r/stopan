# Webhooks

2026-11-12, from roadmap.md ("API later: webhooks for new tickets and
replies"). Another system (a chat room, a monitoring tool, a script)
learns about a new ticket or reply at once, instead of polling the API.

## What is sent, and when

A webhook belongs to one organization and has a URL. When something
happens on a ticket of that organization, the app sends an HTTP `POST`
with a JSON body to the URL.

| event | when |
|---|---|
| `ticket.created` | a ticket is opened, from the app, the public form, email or the API |
| `reply.created` | a public reply is written, by staff, the requester or by email |
| `ping` | the "Send test" button |

- A webhook chooses its events (at least one of the first two).
- **Internal notes are never sent**, nor internal events, files or
  anyone's email address. The body carries names and ids, the ticket's
  subject and description, and the reply's text: what the requester
  sees on the ticket.
- Body:

  ```json
  {
    "event": "reply.created",
    "delivery": "<uuid>",
    "sent_at": "2026-11-12T10:00:00Z",
    "organization": { "id": 1, "name": "Acme" },
    "ticket": { "number": 1042, "reference": "#1042", "subject": "...",
                "description": "...", "status": "open", "priority": "normal",
                "source": "email", "requester": { "id": 7, "name": "Anna" },
                "assignee": null, "created_at": "...", "url": "<the ticket page>" },
    "reply": { "id": 311, "body": "...", "source": "app",
               "author": { "id": 3, "name": "Maria", "role": "agent" },
               "created_at": "..." }
  }
  ```

  `reply` is there only for `reply.created`; `ping` has no `ticket`.
  Text is cut at 20000 characters.
- Headers: `Content-Type: application/json`, `User-Agent: Stopan`,
  `X-Stopan-Event`, `X-Stopan-Delivery` (the uuid) and
  `X-Stopan-Signature: sha256=<hex>`, the HMAC-SHA256 of the exact
  body with the webhook's secret. The receiver checks it to know the
  request came from this Stopan.

## The secret

`whsec_` and 40 random base58 characters, made by the app, never
chosen. It is shown once, right after the webhook is made (as API
tokens are), and stored encrypted (`encrypts`), since the app needs it
to sign. A lost secret means deleting the webhook and making a new one.

## Delivery

- In the background (`WebhookDeliveryJob`, the durable queue of
  notifications.md "Delivery"), after the change is committed, so a
  slow or dead receiver never slows a person down.
- The body is built when the event happens, so a retry sends the same
  body with the same delivery id.
- **Success** is any 2xx answer within 5 seconds to connect and 5 to
  answer. Anything else (another status, a timeout, a refused
  connection, an address that is not allowed) is a failure: the job is
  tried 5 times in all, with growing pauses, then given up.
- The answer's body is not read or stored. Redirects are not followed.
- The webhook remembers its last result: time, HTTP status or a short
  error, and how many deliveries failed in a row. **After 20 failed in
  a row it is switched off** and stays so until an administrator
  switches it on again. A success sets the count to zero.
- A webhook that was deleted or switched off meanwhile sends nothing.

## Which addresses are allowed

The app itself makes the request, from inside the server's network, so
a webhook must not be a way to reach what only the server can reach.

- Only `https://` URLs, at most 500 characters, without a user name or
  password in them.
- The host is resolved at every delivery. If any of its addresses is
  loopback, private (RFC 1918, unique local), link-local, carrier NAT,
  multicast or unspecified, nothing is sent ("address not allowed").
  The request then goes to the address that was checked, with the
  host name kept for TLS and the `Host` header, so a name that changes
  its address between the check and the request does not help.
- A host given as an IP address is checked the same way.
- At most 5 webhooks per organization.

## Who manages them

Super administrators only (org-admins.md lists what organization
administrators may do; sending ticket text to another system is not
among it).

- **Organization page** (`/admin/organizations/:id`), a "Webhooks"
  panel: each webhook with its URL, events, on or off, and the last
  result ("200, 5 minutes ago", "failed: timeout, 3 in a row",
  "never sent"); "Send test", "Switch off" or "Switch on", "Delete"
  (confirm). A form adds one: URL and the two events as check boxes
  (both ticked). After adding, the secret is shown once in the panel
  with a copy button.
- Routes: `POST /admin/organizations/:id/webhooks`,
  `PATCH /admin/webhooks/:id` (`active`), `DELETE /admin/webhooks/:id`,
  `POST /admin/webhooks/:id/ping`.
- **API** (administrators): `GET` and `POST
  /api/v1/organizations/:id/webhooks` (`webhook[url, events[]]`; the
  answer to `POST` carries `secret`, once), `PATCH
  /api/v1/webhooks/:id` (`webhook[active]`), `DELETE
  /api/v1/webhooks/:id`, `POST /api/v1/webhooks/:id/ping`. The secret
  is never in any other answer.
- Deleting an organization deletes its webhooks; flushing its tickets
  keeps them.

## Data model

`webhooks`: `organization_id`, `url`, `secret` (encrypted), `events`
(space-separated), `active` (default true), `failures` (in a row,
default 0), `last_status` (integer), `last_error`, `last_sent_at`,
timestamps.

## Code

- `Webhook` (model): validation, `Webhook.notify(ticket, events)`
  called by `TicketNotifier` after commit, `payload`, `sign`, `ping!`.
- `WebhookSender`: the address check and the request.
- `WebhookDeliveryJob`.

## Acceptance

`test/models/webhook_test.rb`, `test/models/webhook_sender_test.rb`,
`test/jobs/webhook_delivery_job_test.rb`,
`test/controllers/admin/webhooks_controller_test.rb` and the API test:

- a new ticket and a public reply queue one delivery per matching
  active webhook of that organization; an internal note, a status
  change, another organization's webhook, a switched-off webhook and
  an unchosen event queue none;
- the body has no internal note text, no email address; the signature
  verifies with the secret and fails with another;
- URLs that are not https, have credentials or are too long are
  refused; loopback, private, link-local and such addresses are not
  sent to, also when a public-looking name resolves to them; redirects
  are not followed;
- a 2xx records success and clears the failures; other answers and
  errors record a failure and retry; 20 in a row switch the webhook
  off;
- only super administrators manage webhooks (organization
  administrators and agents are refused); the secret is shown once
  and never again, in the page and in the API.

## Security Note

A webhook sends ticket text to a system outside Stopan: add one only
for a receiver the organization trusts, and check the signature on the
receiving side. The secret is stored encrypted and shown once. The
address rules keep webhooks from reaching the server's own network,
and they are checked again at every delivery. Failed deliveries are
retried, so a receiver should treat the delivery id as the key for
doing its work once.
