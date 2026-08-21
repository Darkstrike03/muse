# Security policy

## Reporting a vulnerability

Please do **not** open a public GitHub issue for security problems.

Email the maintainer through GitHub
(https://github.com/Darkstrike03 — use the "Report a vulnerability" button
on this repository's Security tab, or contact details on the profile).
Include:

- Affected version (tag or commit)
- Platform(s) impacted
- Steps to reproduce / proof of concept

You'll get an acknowledgement within 7 days. Fixes are released as patch
versions (`vX.Y.Z+1`) and credited in the changelog unless you prefer to
stay anonymous.

## Scope

Of particular interest:

- Anything that lets an unpaired peer read files beyond explicitly shared
  scopes (the share server must 403 everything else).
- Onion-service/SOCKS layer weaknesses that deanonymize peers.
- Path traversal or injection in the share/cache layers.

Out of scope: vulnerabilities in Tor itself (report upstream at
https://gitlab.torproject.org/tpo/core/team/-/wikis/bug-tracker), libmpv,
Flutter, or the OS; and social engineering of end users.

## Supported versions

Only the latest tagged release receives security fixes.
