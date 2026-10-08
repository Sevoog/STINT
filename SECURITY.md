# Security Policy

## Reporting a vulnerability

**Please don't report security problems in public issues.** Report them privately through GitHub instead: go to the repository's **Security** tab and choose **Report a vulnerability**. Only the maintainer can see the report.

Include what you found, how to reproduce it, and what an attacker could do with it. STINT is maintained by one person, so expect an acknowledgement within about a week. Fixes are prioritized by severity.

## What's in scope

STINT is a network tool that runs unsandboxed and launches system tools on your behalf, so these matter most:

- How STINT launches system tools (ping, traceroute, netstat, nslookup, whois, finger, ifconfig) and passes your input to them.
- Parsing of command output and untrusted network input (Bonjour/mDNS results, port scan responses) that could crash STINT or be exploited.
- Anything that sends data somewhere the [Privacy & Security](README.md#privacy--security) section doesn't say it goes.
- Exported files: what they contain and where they're written.

## Supported versions

Security fixes go into the latest release.
