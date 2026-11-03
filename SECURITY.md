# Security policy

## Supported versions

Releases are tags on `main` (`vX.Y.Z`, see the GitHub releases). Only
the latest release and the latest commit on `main` get security fixes;
a fix lands on `main` and goes out in the next release. There are no
maintained release branches.

## Reporting a vulnerability

Please report vulnerabilities privately, through GitHub's private
vulnerability reporting:

1. Open the repository's **Security** tab.
2. Choose **Report a vulnerability**
   (https://github.com/t0d0r/stopan/security/advisories/new).

Do not open a public issue, pull request or discussion for a
vulnerability before it is fixed.

A useful report says:

- what is affected (page, route, API endpoint, mail handling, ...) and
  the commit you looked at;
- the steps to reproduce it, with the role you used (requester, agent,
  organization administrator, super administrator, or not signed in);
- what an attacker gains, for example reading another organization's
  tickets or internal notes.

## What happens next

- The report is acknowledged, normally within 7 days.
- Once the issue is confirmed, it is fixed on `main` and deployed. A
  GitHub security advisory credits the reporter, unless they ask not to
  be named.
- Please keep the details private until the fix is released.

## Testing rules

- Test against your own instance (`make run` or `make docker-up`, with
  the fictional data of `make demo`), not against servers you do not
  own.
- No denial of service, spam or social engineering.
- Do not access, change or keep data that is not yours. If you reach
  such data by accident, stop and say so in the report.

## Security Note

Reports may contain working exploits; they stay in the private advisory
until a fix is out. Never put credentials or personal data from a real
system in a report.
