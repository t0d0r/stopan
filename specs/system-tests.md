# Browser tests

2026-11-12, from roadmap.md ("browser system tests: headless Chrome
tests for JS behaviour"). The other tests run through Rails without a
browser, so they never run the app's JavaScript. These few do.

## What they are

- `test/system/`, Rails system tests: Capybara drives a headless
  Chrome through Cuprite (the DevTools protocol), against the app
  started inside the test process. Both gems are in the `test` group
  only.
- No driver binary: Cuprite talks to the Chrome that is installed
  (`CHROME_PATH`, else the usual places on macOS and Linux). **Without
  Chrome every test is skipped** with "no Chrome found", so the target
  never fails for that reason.
- A JavaScript error on a page fails the test.
- They test only what needs a browser. Rules, permissions and texts
  stay in the integration tests, which are faster and run everywhere.

## Running

- `make test-system` runs them (`bin/rails test:system`).
- They are **not** part of `make check`: the gate before a commit must
  not depend on a browser being installed. Run them after changes to
  JavaScript, the layout scripts or the forms they cover.
- `bin/rails test` leaves `test/system` out, as Rails does.

## Covered

| test | what only a browser shows |
|---|---|
| sign in and reply | the sign-in form, the password eye, the composer, the reply in the timeline |
| confirm dialog | "Stop sharing" opens the app's dialog; Cancel keeps the link, the button in the dialog stops it |
| reports filters | choosing a period applies at once; "Custom range" shows the dates and Apply; a range applies |
| mail view | the HTML and Text tabs appear, switch the panes, and the frame grows to its content |
| shared page | a password link asks for the password, opens, and counts one view |
| bulk delete | on the search results: selected rows, and the whole list ("Select all N"), through the confirm dialog |
| queue drag | a row dropped on a view tab gets that view's change; a ticked row takes the ticked rows; "All unsolved" only reopens; "All tickets" takes nothing |
| board preview | holding the pointer over a card shows the preview with the request and the latest reply; leaving and Escape hide it; the check box shows none |
| board | ticked cards are ringed and counted, Shift+click ticks a range, Escape clears; dragging a ticked card moves all ticked cards; an unticked card moves alone; cards that may not move stay and are counted; the bar moves without dragging |
| uploads | files picked twice and a dropped file add up in the drop zone's list; one is removed; the reply carries the rest with their content; a file over the size limit is left out and named |
| phones (390 px) | the menu sits behind its button and Escape closes it; the queue, board, search, reports, ticket and Status pages do not scroll sideways; the composer opens from the Reply bar and sends; the Status page's stacked rows name each value |
| shift+click | a range of ticket rows is ticked and cleared and the bar counts them; the member picker's range skips rows its search hides |

## Not covered

Live updates over Action Cable (the test cable adapter does not reach
a browser). Drag and drop on the board, and a file dropped on the drop
zone, are tested with the events a browser fires, not with a real
pointer. Phones are a narrow window of desktop Chrome, not a touch
device. Candidates for later.

## Production image

The image is built without the `development` and `test` groups
(`BUNDLE_WITHOUT="development:test"`, docker.md), so Capybara, Cuprite
and the other test and lint gems are not in it.

## Security Note

The tests start Chrome headless against `127.0.0.1` only, with test
fixtures; they need no network and no credentials. The new gems are
confined to the test group and kept out of the production image.
