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
3. It creates the signed tag on `HEAD` and verifies it against
   `.github/allowed_signers`.
4. It writes the release notes with `bin/release-notes`, from the
   previous tag to the new one, to `tmp/release-notes-vX.Y.Z.md`.
5. If step 3 or 4 fails, the tag is deleted again and nothing is
   pushed. Otherwise it pushes the tag.
6. The push starts the release build on GitHub Actions ("Release build"
   below), which builds the source archive and attests its provenance.
   `bin/release` waits for that run.
7. It downloads the two files from the run, checks them, and signs the
   archive ("Signed release files" below).
8. It creates the GitHub release from the pushed tag (`--verify-tag`),
   titled `Stopan vX.Y.Z`, marked latest, with the notes file and the
   three release files.
9. If step 6, 7 or 8 fails, the tag is public but there is no release
   yet, and nothing unchecked was published. Once the cause is fixed,
   `make release-files VERSION=X.Y.Z` builds the files again and
   creates the release.

The tag is pushed before the files exist, since GitHub can only build
a pushed tag. Signing is checked in step 1, so step 7 rarely fails.

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

## Release build (`.github/workflows/release.yml`, `release-build.yml`)

2026-11-07: the release files are built on GitHub Actions, with SLSA
build provenance. 2026-11-08: at SLSA Build Level 3.

- **Why:** provenance tells anyone who downloads the archive how it was
  built: by this repository's release build, on a GitHub-hosted runner,
  from which commit. It is signed through Sigstore, so it cannot be
  made up afterwards. Provenance from the maintainer's machine would
  prove nothing, which is why the build moved to GitHub. Scorecard's
  Signed-Releases check gives 10 of 10 only to releases with
  provenance (`.intoto.jsonl`); signature files alone give 8.
- **GitHub's attestation action, not the SLSA generator.**
  `actions/attest-build-provenance` makes SLSA v1 build provenance,
  signed through Sigstore. It was chosen over
  `slsa-framework/slsa-github-generator` because:
  - the generator must be referenced by a version tag, never a commit
    SHA, and its release is not immutable, so Scorecard's
    Pinned-Dependencies check would count it as unpinned; the
    attestation action is pinned by SHA like every other action;
  - it is GitHub's own action, and Dependabot updates it with the
    others;
  - the provenance is verified with `gh`, which a release already
    needs, and GitHub also lists it under the repository's
    attestations.
- **SLSA Build Level 3**, in the way GitHub documents it for artifact
  attestations ("Using artifact attestations and reusable workflows to
  achieve SLSA v1 Build Level 3"):
  - **The build and the attestation are in a reusable workflow,**
    `.github/workflows/release-build.yml`. The provenance is signed in
    its name, so `gh attestation verify --signer-workflow
    t0d0r/stopan/.github/workflows/release-build.yml` accepts only
    provenance made there. The calling workflow
    (`.github/workflows/release.yml`) only names the tag; it cannot add
    steps to the reusable workflow's jobs.
  - **The steps that build cannot sign.** Level 3 asks that the
    secret used to sign the provenance is out of reach of the build
    steps. The build job has no `id-token` permission, so it never
    gets the OIDC token that Sigstore signs with. A separate job signs:
    it checks nothing out, runs no project code, and takes from the
    build job only the archive's SHA-256, checked to be 64 hex digits.
  - Level 2 (2026-11-07) had the build and the signing in one job of
    `release.yml`.
- **When:**
  - on the push of a tag `vX.Y.Z`;
  - by hand (`workflow_dispatch`), with an existing tag as input, for
    `make release-files`.

  Each run is named `Release build vX.Y.Z`.
- **Permissions:** none at the top of either file.
  - `release.yml` grants its one job, the call of the reusable
    workflow, `contents: read`, `id-token: write` and
    `attestations: write`: the most that the reusable workflow's jobs
    may then use.
  - The build job has only `contents: read`, to check out the tag.
  - The provenance job has only `id-token: write`, to sign through
    GitHub's OIDC token, and `attestations: write`, to store the
    provenance under the repository's attestations.

  Nothing writes to the repository or its releases. `bin/release`
  uploads the files from the maintainer's machine, after checking
  them.
- **The build job:**
  1. Checks that the tag is `vX.Y.Z`. The tag name reaches the scripts
     only through an environment variable, never as an expression in
     the script.
  2. Checks out the tag, without keeping the token
     (`persist-credentials: false`), and checks that `HEAD` is the
     tag's commit.
  3. Verifies the tag's signature against `.github/allowed_signers` of
     the tag. v0.1.0, the one unsigned tag, is the only exception.
  4. Builds `stopan-X.Y.Z.tar.gz`: `git archive` of the tag, with the
     prefix `stopan-X.Y.Z/` and `tar.umask` 0002 (git's default,
     stated so that a local setting cannot change the comparison in
     `bin/release`).
  5. Hands the archive's SHA-256 to the provenance job as a job output,
     and uploads the archive as the run artifact `release-archive`.
- **The provenance job:**
  1. Checks the tag again and that the SHA-256 is 64 hex digits; the
     archive name comes from the tag, not from the build job.
  2. Attests the provenance of `stopan-X.Y.Z.tar.gz` with that digest.
  3. Uploads the attestation, a Sigstore bundle on one JSON line, as
     `stopan-X.Y.Z.tar.gz.intoto.jsonl` in the run artifact
     `release-provenance`.

  Both artifacts are kept 7 days.
- **A run by hand names `main` as its source.** The workflow runs from
  `main` and checks out the tag. v0.1.0 and v0.1.1 were tagged before
  the workflow existed, so their provenance was made this way.
- **Pinned actions**, by commit SHA with the version in a comment, as
  in ci.md. The reusable workflow is called by its path in this
  repository (`./.github/workflows/release-build.yml`), so it is the
  version of the same commit; Scorecard counts such a reference as
  pinned.

  | action | version |
  |--------|---------|
  | `actions/checkout` | v7.0.1 |
  | `actions/attest-build-provenance` | v4.2.2 |
  | `actions/upload-artifact` | v7.0.2 |

## Signed release files

2026-11-06: every release carries a source archive and its signature.
2026-11-07: and its build provenance. The archive is built by the
release build, no longer on the maintainer's machine.

- **Why:** a signed tag is checked with git; a signed file can be
  checked by anyone who downloads it, without a clone. Scorecard's
  Signed-Releases check looks for signature files (`.sig` and others)
  and provenance files (`.intoto.jsonl`) among the release files.
- **The files**, attached to the GitHub release:
  - `stopan-X.Y.Z.tar.gz`: `git archive` of the tag, with the prefix
    `stopan-X.Y.Z/`, built by the release build. It holds exactly the
    released commit. GitHub's own source archives stay as they are.
  - `stopan-X.Y.Z.tar.gz.intoto.jsonl`: its build provenance (above).
  - `stopan-X.Y.Z.tar.gz.sig`: its SSH signature (`ssh-keygen -Y sign`,
    namespace `file`), made with the release signing key through
    ssh-agent.
- **Checked before signing**, on the maintainer's machine, by
  `bin/release`:
  - the run succeeded, and its two artifacts hold exactly the archive
    and its provenance;
  - a run from the tag push built the tag's own commit; a run by hand
    ran from a commit on `main`;
  - `gh attestation verify` with the bundle: signed for this
    repository by `.github/workflows/release-build.yml`, on a
    GitHub-hosted runner, from the run's commit and ref;
  - the archive holds exactly the tag: unpacked, it is byte for byte
    the tar that `git archive` makes locally from the tag. The tar is
    the same across git versions; only the gzip layer differs between
    machines, so the compressed bytes are not compared.
- **Then signed and checked:** the signature is verified against
  `.github/allowed_signers` (`ssh-keygen -Y find-principals`, then
  `-Y verify`). If any check fails, nothing is uploaded.
- **What the signature means:** the maintainer checked that the
  archive GitHub built is exactly the signed tag.
- **Anyone can verify a download:**

  ```sh
  ssh-keygen -Y verify -f allowed_signers -I t0d0r -n file \
    -s stopan-X.Y.Z.tar.gz.sig < stopan-X.Y.Z.tar.gz
  gh attestation verify stopan-X.Y.Z.tar.gz --repo t0d0r/stopan \
    --signer-workflow t0d0r/stopan/.github/workflows/release-build.yml
  ```

  `allowed_signers` is `.github/allowed_signers` from the repository.
  `gh attestation verify` reads the provenance from GitHub; with
  `--bundle stopan-X.Y.Z.tar.gz.intoto.jsonl` it uses the release file
  instead.
- **Earlier releases, and a release that failed after its tag was
  pushed:** `make release-files VERSION=X.Y.Z` starts the release build
  by hand for an existing tag, waits for it, checks and signs the
  files the same way, and attaches all three, replacing files of the
  same name. When the tag has no release yet, it creates the release,
  with the notes.
- **v0.1.0 and v0.1.1:** they first got a locally built archive and its
  signature (2026-11-06), then an archive from the release build with
  provenance and a new signature (2026-11-07). The rebuilt archives
  hold the same files, but their bytes and checksums changed, since
  the gzip layer comes from another machine. After that, Scorecard's
  Signed-Releases check was 10.
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
  archive are signed and the archive has build provenance, with the
  commands to verify both; report vulnerabilities as SECURITY.md says;
  only the latest release and `main` get fixes.

## Not in this phase

- The reusable build workflow in a repository of its own. It would let
  other people own the build than own Stopan; with one maintainer it
  adds nothing, and GitHub's Level 3 guide allows the same repository.
- Signed commits.
- Container images as release files: the server builds the image from
  the source (deploy.md).
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
- `bin/release` signs and verifies the tag before it pushes it, and
  checks the run, the provenance and the archive before it signs the
  archive and publishes (test/config/release_test.rb).
- `.github/workflows/release.yml` and `release-build.yml` pass
  `actionlint`, pin their actions by SHA, and put no expression into a
  script. Only the provenance job can get the OIDC token; the build
  job has `contents: read` and nothing else (test/config/release_test.rb,
  test/config/github_test.rb).
- The provenance of a release is signed by `release-build.yml`:
  `gh attestation verify` with `--signer-workflow` naming it passes,
  and naming `release.yml` fails.
- Every release from v0.1.0 on has `stopan-X.Y.Z.tar.gz`,
  `stopan-X.Y.Z.tar.gz.intoto.jsonl` and `stopan-X.Y.Z.tar.gz.sig`;
  both verify commands above pass on the downloaded files; Scorecard's
  Signed-Releases check is 10.
- `bin/release-notes` groups the commits as above, lists breaking
  changes first, leaves out the working notes, and quotes `@name` and
  `#123` (test/bin/release_notes_test.rb).
- After `make release VERSION=0.1.0`: the tag `v0.1.0` is on GitHub at
  the released commit, and the release `Stopan v0.1.0` is the latest.

## Security Note

Release notes are public and built from commit subjects, which already
follow the rule of no secrets, personal data or private URLs. Release
tags and release files are signed with a separate SSH key that has a
passphrase and never leaves the maintainer's machine. Its public half
is committed and registered on GitHub; the private half is never
written to the repository, a note or a log. The release build cannot
write to the repository or its releases; what it makes is treated as
untrusted until `bin/release` has checked it. Its provenance is public
(Sigstore's transparency log) and names only the repository, the
workflow, the commit and the runner. Only the latest release gets
security fixes.
