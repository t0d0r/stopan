# Reports

Operator, 2026-10-27: "create a page for statistical reports". One page,
`GET /reports`, for staff: how many tickets come in and get done, how
big the backlog is, how fast the desk answers and solves, per
organization and per person. It is the "reporting" item of roadmap.md.

## Who sees what

- Agents and administrators; requesters get 403. A "Reports" pill in the
  menu bar (blue square) after "New ticket", shown to staff only.
- Every number counts only tickets the viewer may see
  (`Ticket.visible_to`): an agent sees their organizations, an
  administrator all. Comments count only on those tickets.

## Filters

One row above everything, GET parameters, applied to the whole page:

| param | values | default |
|---|---|---|
| `period` | `7d`, `30d`, `90d` (today and the 6, 29 or 89 days before it), `12m` (this month and the 11 before it); up to now | `30d` |
| `organization` | id of a visible organization, or empty for all | all |

Unknown values fall back to the default. The selects apply at once with
JavaScript (the queue's `data-auto-submit`), with an Apply button inside
`<noscript>`.

## Definitions

Times are calendar time (no business hours), in the app's time zone.

- **New:** tickets created in the period.
- **Done:** tickets whose status is Done now and whose `done_at` is in
  the period (a ticket reopened later is not counted, because reopening
  clears `done_at`).
- **Open now:** tickets that are not Done (New, In progress, Pending,
  Not now), whatever the period.
- **First response time:** for tickets created in the period, from
  `created_at` to the first public reply by a staff member. Tickets
  without one are counted as "still waiting for a first reply".
- **Resolution time:** for Done tickets of the period, `created_at` to
  `done_at`.
- Times show the **median** (half of the tickets were faster), not the
  mean, so one old ticket does not distort it. Formatted as minutes,
  hours and minutes, or days and hours ("45 min", "3 h 20 min",
  "2 d 4 h"); "-" when there is nothing to measure.

## Page

1. **Stat tiles** (no chart): New, Done, Open now, Median first response,
   Median resolution. New and Done show the change against the previous
   period of the same length ("+3 vs previous 30 days"), as text, never
   colour alone. First response adds "N still waiting".
2. **Created and done over time:** grouped columns, two series (Created,
   Done), one group per day (7d, 30d), week (90d, weeks start on Monday)
   or month (12m). Legend above the chart. Colours from the dataviz
   reference palette, validated on the panel paper `#efeeea` (which keeps
   its colour in the dark theme): Created `#2a78d6`, Done `#eb6834`; Done
   is below 3:1 against the paper, so the legend, the tooltip and the
   table carry the values. Columns at most 24px wide each, 4px rounded
   tops, square at the baseline, a 2px gap between the pair; hairline
   gridlines with rounded ticks; date labels thinned to fit. Hovering or
   focusing a group shows a tooltip with the date and both values (plain
   text, `textContent`); each group also has an SVG `<title>`. A "Show as
   table" disclosure under the chart lists every bucket.
3. **Open now by status:** one row per status (and stage) with its count
   and a thin single-hue bar (`#2a78d6`) proportional to the largest.
4. **By organization:** table with New, Done, Open now, median first
   response, median resolution, for each visible organization with any
   ticket; sorted by Open now, then name.
5. **By person:** table of active staff who have tickets assigned now or
   activity in the period: Open assigned now, Done in the period (as
   assignee), Public replies and Internal notes written in the period,
   median first response of the tickets where they wrote the first
   staff reply.

The page is plain server-rendered HTML and inline SVG (CSP: no external
scripts or styles). It is not live-updated; reloading recalculates.

## Code

- `TicketReport` (model, no table): built from user and params, exposes
  the filter, tiles, buckets, status rows, organization rows and person
  rows. Medians are computed in Ruby from plucked timestamps (SQLite has
  no percentile function).
- `ReportsController#show`, `reports/show.html.erb`, helpers for
  durations and the SVG chart.

## Tests

Requesters 403; agents see only their organizations' numbers; the
definitions above on known fixtures (new, done, reopened not done,
first response by staff only and public only, medians, waiting count);
period and organization filters and their fallbacks; buckets per period;
the chart has a legend, titles and a table; German and Bulgarian render.

## Later

CSV export, custom date ranges, business hours, SLA targets
(roadmap.md "SLAs").

## Security Note

Reports aggregate only what the viewer may already see; they show names
of organizations and staff but no ticket text. The organization filter
accepts only visible organizations, so an agent cannot read counts of
another organization by guessing its id.
