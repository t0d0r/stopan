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
- only the latest `main` gets fixes;
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

## Not in this phase

- Dependabot or Renovate updates for the pinned actions, base image
  digests and gems (the Dependency-Update-Tool check).
- A test workflow that runs `make check` on GitHub; checks run locally
  before each commit.
- A `repo_token` for the full Branch-Protection check.

## Acceptance

- `actionlint .github/workflows/scorecard.yml` passes.
- After a push to `main` the run succeeds, the Code scanning page lists
  the Scorecard results, and both badges show.

## Security Note

The workflow runs third-party actions with permission to write code
scanning alerts and to request an OIDC token. Pinning to commit SHAs
keeps a moved or compromised tag from changing the code that runs, and
`read-all` keeps the token from writing to the repository. Published
results are public, as is the repository.
