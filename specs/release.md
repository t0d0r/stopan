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
- Tags are signed (`git tag -s`, below), with the message `Stopan vX.Y.Z`.
  v0.1.0 is the one unsigned tag; it was published before signing.

## How to release

`make release VERSION=X.Y.Z` (without the leading `v`) runs
`bin/release`:

1. It refuses, with a message, when:
   - `VERSION` is missing or not three numbers;
   - `gh` is missing or not signed in;
   - signing is not set up: `gpg.format` is not `ssh`, `user.signingkey`
     is not set or its file is missing, the key is not in
     `.github/allowed_signers`, or ssh-agent does not hold it;
   - the branch is not `main`;
   - tracked files have uncommitted changes (untracked files are
     ignored);
   - `HEAD` differs from `origin/main` after a fetch (push first);
   - the tag already exists.
2. It runs `make check`.
3. It writes the release notes with `bin/release-notes` to
   `tmp/release-notes-vX.Y.Z.md`, before the tag exists, so they cover
   the commits since the previous tag.
4. It creates the signed tag on `HEAD` and verifies it against
   `.github/allowed_signers`.
5. It builds the source archive from the tag, signs it and verifies the
   signature ("Signed release files" below).
6. If a check in step 4 or 5 fails, the tag is deleted again and
   nothing is pushed. Otherwise it pushes the tag.
7. It creates the GitHub release from the pushed tag (`--verify-tag`),
   titled `Stopan vX.Y.Z`, marked latest, with the notes file and the
   two release files.

A release does not deploy. A deploy follows deploy.md and records the
revision; when it runs a tagged commit, the record names the tag too.
`make deploy` ships `HEAD`, so a release is deployed from its tag:

```sh
git switch --detach vX.Y.Z
DEPLOY_HOST=<host> make deploy
git switch main
```

Commits after the tag (notes, records) are then not shipped.

## Signed tags

2026-11-05: release tags are signed with SSH (git `gpg.format=ssh`).

- **Why:** a signed tag shows that the release came from the
  maintainer's key, not only from someone who can push to GitHub.
- **A separate ed25519 key, only for signing.** It is not used to log
  in anywhere. A leaked login key cannot sign a release, and a leaked
  signing key opens no server.
- **SSH, not GPG:** ssh-agent is already in use, there is no keyring to
  keep, and GitHub verifies both.
- **The private key** has a passphrase and stays on the maintainer's
  machine. ssh-agent holds it (on macOS with the keychain:
  `ssh-add --apple-use-keychain <private key>`), so `make release` signs
  without a prompt.
- **Git config in this repository only** (`.git/config`, not
  committed):
  - `gpg.format ssh`;
  - `user.signingkey <path of the public key>`: git asks ssh-agent for
    the private key;
  - `tag.gpgSign true`: every annotated tag is signed;
  - `gpg.ssh.allowedSignersFile <absolute path of
    .github/allowed_signers>`, so `git tag -v` works.
- **`.github/allowed_signers`** (committed) lists the keys that may
  sign releases. Each line has:
  - the principal `t0d0r`, the GitHub account, never an email address;
  - `namespaces="git,file"`: the key signs tags (`git`) and release
    files (`file`), nothing else;
  - the public key, without its comment (which would name the machine).
- **Anyone can verify a tag** from a clone:
  `git -c gpg.ssh.allowedSignersFile=.github/allowed_signers tag -v vX.Y.Z`.
- **On GitHub** the same public key is added to the account as a
  *signing* key, so tags and releases show "Verified". GitHub matches
  the tagger email with the account's verified emails.
- **Changing the key:**
  - a replaced key keeps its line with `valid-before="YYYYMMDD"`, so
    older tags still verify;
  - a leaked key is removed from the file and from GitHub.
- **Commits stay unsigned.** Only releases are signed.

## Signed release files

2026-11-06: every release carries a source archive and its signature.

- **Why:** a signed tag is checked with git; a signed file can be
  checked by anyone who downloads it, without a clone. It also answers
  Scorecard's Signed-Releases check, which looks for signature files
  among the release files (`.sig` and others). That check gives 8 of 10
  when every release has a signature, and 10 only with SLSA provenance
  (below, "Not in this phase").
- **The files**, attached to the GitHub release:
  - `stopan-X.Y.Z.tar.gz`: `git archive` of the tag, with the prefix
    `stopan-X.Y.Z/`. Built from the tag, never from the working copy,
    so it holds exactly the released commit. GitHub's own source
    archives stay as they are.
  - `stopan-X.Y.Z.tar.gz.sig`: its SSH signature (`ssh-keygen -Y sign`,
    namespace `file`), made with the release signing key through
    ssh-agent.
- **Checked before upload:** the signature is verified against
  `.github/allowed_signers` (`ssh-keygen -Y find-principals`, then
  `-Y verify`); if that fails, nothing is uploaded.
- **Anyone can verify a download:**

  ```sh
  ssh-keygen -Y verify -f allowed_signers -I t0d0r -n file \
    -s stopan-X.Y.Z.tar.gz.sig < stopan-X.Y.Z.tar.gz
  ```

  `allowed_signers` is `.github/allowed_signers` from the repository.
- **Earlier releases:** `make release-files VERSION=X.Y.Z` builds,
  signs, verifies and attaches the two files to an existing release,
  from its tag. It replaces files of the same name. v0.1.0 and v0.1.1
  got their files this way.
- **The release notes say how to verify** (their Security Note).

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
- **Ends with a "Security Note"** section: the tag and the source
  archive are signed, with the command to verify the archive; report
  vulnerabilities as SECURITY.md says; only the latest release and
  `main` get fixes.

## Not in this phase

- SLSA provenance (`.intoto.jsonl`), which Scorecard needs for 10 of
  10 in Signed-Releases. It has to be made by a build on GitHub Actions
  (the SLSA generator), while releases are made on the maintainer's
  machine.
- Signed commits.
- Release files (archives, images): the server builds the image from
  the source (deploy.md); GitHub adds the source archives itself.
- A `CHANGELOG.md`: the release notes on GitHub are the change log.
- Release branches: fixes go to `main` and into the next release.

## Acceptance

- `make release` refuses in each case of step 1, before `make check`.
- A new release tag is signed: `git tag -v` with
  `.github/allowed_signers` prints a good signature for `t0d0r`, and
  GitHub shows the tag as "Verified".
- `.github/allowed_signers` has only lines with a principal without
  `@`, `namespaces="git,file"` and an ed25519 key without a comment
  (test/config/release_test.rb).
- Every release from v0.1.0 on has `stopan-X.Y.Z.tar.gz` and
  `stopan-X.Y.Z.tar.gz.sig`; the verify command above prints a good
  signature for `t0d0r`; `bin/release` builds, signs and verifies the
  files before it pushes the tag.
- `bin/release-notes` groups the commits as above, lists breaking
  changes first, leaves out the working notes, and quotes `@name` and
  `#123` (test/bin/release_notes_test.rb).
- After `make release VERSION=0.1.0`: the tag `v0.1.0` is on GitHub at
  the released commit, and the release `Stopan v0.1.0` is the latest.

## Security Note

Release notes are public and built from commit subjects, which already
follow the rule of no secrets, personal data or private URLs. Release
tags and release files are signed with a separate SSH key that has a
passphrase and never leaves the maintainer's machine. Its public half is committed and
registered on GitHub; the private half is never written to the
repository, a note or a log. Only the latest release gets security
fixes.
