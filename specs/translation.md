# Translating messages (DeepL)

Operator, 2026-10-27: a "Translate" button on messages ("yes, option 2
with a Translate button", provider "DeepL API"). A customer writes in
German, an agent reads Bulgarian: the agent clicks "Translate" under the
message and reads a machine translation into their own UI language, with
the original left as it is.

## Who and where

- Staff only (agents and administrators), on the ticket page. Requesters,
  shared pages (sharing.md) and emails never show the button or a
  translation.
- Every message of the timeline that has text: the original request
  (description), public replies and internal notes. Staff can read all of
  them already; translation shows nothing new to anyone.
- Target language: the viewer's current UI language (ui.md "Language"):
  English, Bulgarian or German. DeepL detects the source language.

## Switching it on

- The DeepL API key is entered by an administrator on `/admin/settings`
  (operator, 2026-10-27: "key to be added via settings"), in the
  "Machine translation (DeepL)" panel, never in the repository. It is
  stored encrypted (`app_settings.deepl_api_key`, Active Record
  encryption with keys derived from `SECRET_KEY_BASE`, as for the
  organizations' mail passwords, organization-mail.md) and is
  write-only: the form never shows it ("A key is stored. Leave empty to
  keep it." / "No key stored."), a blank field keeps it, and "Remove the
  stored key" clears it. `DEEPL_API_KEY` in the environment is used only
  when no key is stored.
- A key ending in `:fx` is a DeepL API Free key and uses
  `https://api-free.deepl.com`; any other key uses
  `https://api.deepl.com`. `DEEPL_API_URL` (environment) overrides the
  base URL (tests, a proxy).
- The same panel has the switch "Offer a Translate button on messages
  for staff", off by default, with the note "Message text is sent to
  DeepL to be translated. Turn this on only if your organization allows
  it." Switching it on without a key is refused with "DeepL API key is
  needed before translation can be switched on".
- The button shows only when the setting is on and a key is present.
  Requests while it is off answer 403.

## Behaviour

- Under each message's text a small "Translate" button (a form button,
  works without JavaScript). Click -> `POST
  /tickets/:number/translations` with `message=description` or
  `message=comment-<id>`.
- The server checks: staff, the ticket is visible to the user
  (`Ticket.visible_to`), the comment belongs to the ticket, the setting is
  on. It sends the message's current text (at most 20,000 characters;
  longer text answers "This message is too long to translate.") to DeepL
  `POST /v2/translate` (`text`, `target_lang` BG, DE or EN-GB,
  `Authorization: DeepL-Auth-Key ...`), with a 10 second timeout.
- The result is stored (table `translations`): message (polymorphic
  ticket description or comment), target language, detected source
  language, translated text, and a SHA-256 of the original text it was
  made from. A later view by any staff member in the same language reuses
  it; editing the message makes it stale (the digest no longer matches),
  so the button shows again. A new translation of the same message and
  language replaces the old row.
- The ticket page then shows, under the message, a dashed block "Machine
  translation (DeepL), original: German" (the language named in the
  viewer's language, so no grammar case changes it) with the text, and a "Hide" button
  that folds it back to the small "Translate" button (operator,
  2026-10-27: "hiding removes the whole translation; let it go back to
  the Translate button"). That button then shows the stored translation
  again at once, without asking DeepL; the choice holds across live
  refreshes of the page. Without JavaScript the block stays. Plain messages render the translation as plain text with
  line breaks; Markdown messages render it through the same sanitized
  Markdown pipeline (markdown.md). If DeepL says the source is already
  the target language, the block says "This message is already in
  Bulgarian." instead.
- After the POST the page returns to the message (redirect to the ticket
  with its anchor, like other message actions).
- Failures (DeepL down, timeout, quota, a bad key) store nothing and show
  the alert "The translation did not work. Try again later." The error is
  logged without the message text or the key.
- Rate limit: 30 translations per minute per user (Rails `rate_limit`),
  then "Too many translations. Wait a minute."
- No ticket event: a translation does not change the ticket and does not
  appear in the timeline, notifications or live updates.

## Data model

`app_settings`: `translation_enabled` (boolean, default false),
`deepl_api_key` (encrypted text, nullable).

`translations`: `translatable_type`, `translatable_id` (Ticket for the
description, Comment), `target_language` (`en`/`bg`/`de`),
`source_language` (DeepL's code, lower case, may be any language),
`text`, `source_digest` (SHA-256 hex of the original), timestamps.
Unique index on (`translatable_type`, `translatable_id`,
`target_language`). Rows go with their message (`dependent: :delete_all`).

## Code

- `DeeplClient`: one method, `translate(text, target:) -> [text,
  source]`, raises `DeeplClient::Error` on any failure. Tests replace it
  through `Translation.client`, no network.
- `Translation.for(message, language)` returns a current translation or
  nil; `Translation.translate!(message, language)` calls the client and
  stores the row.
- `TranslationsController#create` (nested under tickets).

## Tests

Button only for staff, only when on and keyed; requesters and shared
pages never see it; 403 when off; a comment of another ticket is 404;
the stored row is reused and goes stale after an edit; the translation
block and the "already in" text; failure and too-long messages store
nothing and show the alert; the request DeepL gets (target codes, auth
header, base URL for `:fx` keys) with a fake HTTP layer.

## Security Note

Translating sends message text, which may contain personal data, to
DeepL, outside this server. That is why it is off by default, switched
on by an administrator, staff only, and one message per explicit click;
nothing is translated in the background. Check DeepL's data terms for
the plan in use (Free and Pro differ) before switching it on. The key
is stored encrypted, never shown again after saving, never logged
(`filter_parameters` covers `_key`), and the translated text
is escaped or sanitized like any user text.
