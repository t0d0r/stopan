# Releases

2026-11-03: the first release is v0.1.0. Before it, Stopan was deployed
from `main` without versions (deploy.md names each revision).

## Versions

- **Semantic Versioning**, tags `vMAJOR.MINOR.PATCH` on `main`.
- **0.x for now.** While the major version is 0, the API (`/api/v1`,
  api.md) and the data may still change in a breaking way; such a change
  raises the minor version. 1.0.0 will declare them stable; after that
  a breaking change raises the major version.
- **Which number goes up**, judged from the commits since the previous
  tag (Conventional Commits):
  - a breaking change (`type!:` or a `BREAKING CHANGE:` footer): major,
    or minor while at 0.x;
  - any `feat`: minor;
  - otherwise (fixes, dependencies, other changes): patch.
- **The git tag is the only place the version is kept.** Nothing in the
  tree repeats it, so a release needs no commit, and a file can never
  disagree with the tag.
- Tags are annotated (`git tag -a`), with the message `Stopan vX.Y.Z`.

## How to release

`make release VERSION=X.Y.Z` (without the leading `v`):

1. It refuses, with a message, when:
   - `VERSION` is missing or not three numbers;
   - `gh` is missing or not signed in;
   - the branch is not `main`;
   - tracked files have uncommitted changes (untracked files are
     ignored);
   - `HEAD` differs from `origin/main` after a fetch (push first);
   - the tag already exists.
2. It runs `make check`.
3. It writes the release notes with `bin/release-notes` to
   `tmp/release-notes-vX.Y.Z.md`, before the tag exists, so they cover
   the commits since the previous tag.
4. It creates the annotated tag on `HEAD` and pushes the tag.
5. It creates the GitHub release from the pushed tag (`--verify-tag`),
   titled `Stopan vX.Y.Z`, marked latest, with the notes file.

A release does not deploy. A deploy follows deploy.md and records the
revision; when it runs a tagged commit, the record names the tag too.

## Release notes (`bin/release-notes [FROM] [TO]`)

- **Range:** `FROM` defaults to the newest tag reachable from `TO`;
  without any tag, the notes cover every commit. `TO` defaults to `HEAD`.
- **First line:** "Changes since vX.Y.Z." or, for the first release,
  "First release: every change since the start of the project."
- **Sections**, in this order, each left out when empty:
  1. Breaking changes (`type!:` or a `BREAKING CHANGE:` footer),
     whatever the type;
  2. Features (`feat`);
  3. Fixes (`fix`);
  4. Performance (`perf`);
  5. Dependencies (scope `deps`, any type);
  6. Documentation (`docs`);
  7. Other changes (`refactor`, `style`, `test`, `build`, `ci`,
     `chore`, `revert`, and subjects that are not Conventional Commits).
- **Left out:** `docs(session)`, `docs(deploy)` and `docs(todo)`. They are
  working notes and deploy records, not changes to Stopan.
- **Each line:** `- **scope:** description (short hash)`, oldest first;
  without a scope, `- description (short hash)`.
- **No mentions or links by accident:** `@name` and `#123` in a subject
  are put in backticks, so GitHub neither notifies anyone nor links an
  issue.
- **Ends with a "Security Note"** section: report vulnerabilities as
  SECURITY.md says; only the latest release and `main` get fixes.

## Not in this phase

- Signed tags and signed release files (Scorecard's Signed-Releases
  check): there is no signing key set up yet.
- Release files (archives, images): the server builds the image from
  the source (deploy.md); GitHub adds the source archives itself.
- A `CHANGELOG.md`: the release notes on GitHub are the change log.
- Release branches: fixes go to `main` and into the next release.

## Acceptance

- `make release` refuses in each case of step 1, before `make check`.
- `bin/release-notes` groups the commits as above, lists breaking
  changes first, leaves out the working notes, and quotes `@name` and
  `#123` (test/bin/release_notes_test.rb).
- After `make release VERSION=0.1.0`: the tag `v0.1.0` is on GitHub at
  the released commit, and the release `Stopan v0.1.0` is the latest.

## Security Note

Release notes are public and built from commit subjects, which already
follow the rule of no secrets, personal data or private URLs. The tag
is not signed; a signed tag and signed release files are the next step
for supply-chain checks. Only the latest release gets security fixes.
