# Continuous integration (GitHub Actions)

2026-11-02: the README shows the OpenSSF Scorecard badge and the status of
the Scorecard GitHub Action. The repository on GitHub is public, which the
published results and the badge need.

## Scorecard workflow

`.github/workflows/scorecard.yml` runs `ossf/scorecard-action`, which
checks the repository against the OpenSSF supply-chain checks (pinned
dependencies, token permissions, branch protection, maintained, security
policy, and others).

- **When:**
  - on every push to `main`;
  - weekly (Monday, 05:27 UTC), so the Maintained check stays current;
  - when a branch protection rule changes;
  - by hand (`workflow_dispatch`).
  It runs only on the default branch, since results can be published only
  from there.
- **Permissions:** `read-all` at the top. The job adds only:
  - `security-events: write`, to upload the results to code scanning;
  - `id-token: write`, to publish the results to the Scorecard API.
- **Steps:**
  1. checkout, with `persist-credentials: false`;
  2. the analysis, to `results.sarif`, with `publish_results: true`;
  3. the SARIF file as a run artifact, kept 5 days;
  4. the SARIF file to code scanning (`github/codeql-action/upload-sarif`).
- **Pinned actions:** every action is pinned to a full commit SHA, with
  the version in a comment. Scorecard's Pinned-Dependencies check asks for
  this, and a moved tag cannot change what runs.

  | action | version |
  |--------|---------|
  | `actions/checkout` | v7.0.1 |
  | `ossf/scorecard-action` | v2.5.0 |
  | `actions/upload-artifact` | v7.0.2 |
  | `github/codeql-action/upload-sarif` | v4.39.1 |

  To update one, take the commit SHA of the new release tag and change
  the comment with it.
- **No secrets.** The workflow uses the job's own token only. Without a
  personal access token (`repo_token`) the Branch-Protection check cannot
  read every setting, so it may score lower; that is accepted.

## Release build workflow

2026-11-07: `.github/workflows/release.yml` builds the source archive
of a release tag and attests its SLSA build provenance. 2026-11-08: it
calls the reusable workflow `.github/workflows/release-build.yml`,
which does the work in two jobs, for SLSA Build Level 3. release.md
"Release build" describes both. They follow the same rules as the
Scorecard workflow:
- actions pinned to commit SHAs (`actions/checkout`,
  `actions/attest-build-provenance`, `actions/upload-artifact`); the
  reusable workflow is called by its path in this repository
  (`./.github/workflows/release-build.yml`), which Scorecard counts as
  pinned and test/config/github_test.rb allows;
- no secrets, only the jobs' own tokens;
- no permissions at the top. The build job has `contents: read` only;
  the provenance job has `id-token: write` and `attestations: write`
  only. Neither can write to the repository or its releases.

## Badges

Under the title in `README.md`:

- **OpenSSF Scorecard:** the score from `api.scorecard.dev` for
  `github.com/t0d0r/stopan`, linking to the Scorecard viewer.
- **Scorecard GitHub Action:** the status of the last workflow run,
  linking to the workflow's runs.

The score badge shows a result only after the first run on `main` has
published one.

## Security policy (`SECURITY.md`)

2026-11-02, for Scorecard's Security-Policy check. `SECURITY.md` at the
root says:
- only the latest release and the latest `main` get fixes; there are no
  release branches (release.md);
- how to report: GitHub's private vulnerability reporting (Security tab,
  "Report a vulnerability"), never a public issue;
- what a useful report holds;
- what happens next: acknowledged normally within 7 days, fixed on
  `main` and deployed, credited in a GitHub security advisory;
- the testing rules: own instance with demo data, no denial of service,
  no other people's data.

It names no personal address. The reporting channel works only while
private vulnerability reporting is on in the repository settings.

Base images pinned by digest for Pinned-Dependencies: docker.md "Pinned
base images".

The License check is answered by `LICENSE` (BSD 2-Clause, overview.md
"License").

## Dependency updates (Dependabot)

2026-11-03: `.github/dependabot.yml` asks Dependabot for version updates
of the GitHub Actions and the gems. This answers Scorecard's
Dependency-Update-Tool check, and replaces updating the pinned action
SHAs by hand.

- **GitHub Actions** (`.github/workflows`):
  - weekly, on Monday;
  - one grouped pull request for all actions;
  - Dependabot keeps the commit SHA pins and updates the version
    comment next to them;
  - commit prefix `ci(deps)`.
- **Gems** (`Gemfile`, `Gemfile.lock`):
  - weekly, on Monday;
  - minor and patch updates in one grouped pull request; each major
    update in its own;
  - at most 5 open pull requests;
  - commit prefix `chore(deps)`, `chore(deps-dev)` for development and
    test gems.
- **Cooldown:** a new release is proposed only after it has been
  public for a while: 7 days by default, 3 for patch, 7 for minor, 30
  for major. A hijacked or broken release is usually found and pulled
  within days; waiting keeps it out.
- **No auto-merge.** There is no test workflow on GitHub (below). A
  Dependabot pull request is merged only after its branch passes
  `make check` locally; a deploy follows the usual steps
  (specs/deploy.md).
- **Base image digests are not covered.** The Dockerfiles name the Ruby
  image by digest only (docker.md "Pinned base images"), so Dependabot
  cannot tell which tag to follow. The digest is still updated by hand.
- **Dependabot alerts and security updates** are repository settings,
  separate from this file. Both are on (2026-11-03). Alerts list known
  advisories for the locked gems and pinned actions. Security updates
  open a pull request as soon as an alert has a fixed release, without
  the cooldown and outside the weekly run; they follow the groups and
  prefixes above. They are merged the same way: only after `make check`
  passes locally, never automatically.
- **Security fixes do not wait for the weekly run.** `make audit`
  (bundler-audit and the Ruby advisory database) lists every vulnerable
  gem, indirect ones included, and often before GitHub shows an alert.
  A vulnerable gem is moved to its fixed release with
  `bundle update --conservative <gems>`, then `make check`, commit and
  deploy. The open Dependabot pull request for the same gems closes by
  itself once `main` has them. First done 2026-11-03: sqlite3, crass,
  loofah, nokogiri, rack and rails-html-sanitizer.

## Gem audit in `make check`

2026-11-03: `make check` runs `lint`, `audit` and `test`. A commit is
blocked while `Gemfile.lock` holds a gem with a known advisory, so a
vulnerable gem is found at the next commit, not weeks later.

- **The advisory database is updated first.** `make audit` updates the
  Ruby advisory database (a git checkout in the user's data directory,
  `~/.local/share/ruby-advisory-db`, the tool's cache), then checks
  `Gemfile.lock` against it.
- **Offline still works.** When the update fails (no network), the
  target prints a warning and checks against the local copy. Only when
  there is no local copy at all does it fail, since then nothing can
  be checked.
- **An advisory that does not apply, or that has no fixed release yet,**
  goes on the ignore list in `config/bundler-audit.yml`. It needs a comment
  with the reason and the date; the entry is removed once a fixed
  release exists. Without a reason it is not added.
- **Acceptance:** `make check` prints the audit result and fails when
  `bin/bundler-audit check` fails; with the network off and a local
  copy present, it warns and still checks.

## Not in this phase

- Dependabot updates of the base image digest (it would need
  `ruby:<tag>@sha256:<digest>`, which Podman may not accept).
- A test workflow that runs `make check` on GitHub; checks run locally
  before each commit.
- A `repo_token` for the full Branch-Protection check.

## Acceptance

- `actionlint` passes for both workflows.
- After a push to `main` the run succeeds, the Code scanning page lists
  the Scorecard results, and both badges show.

## Security Note

The workflow runs third-party actions with permission to write code
scanning alerts and to request an OIDC token. Pinning to commit SHAs
keeps a moved or compromised tag from changing the code that runs, and
`read-all` keeps the token from writing to the repository. Published
results are public, as is the repository.
