# Contributing to STINT

Thanks for your interest in STINT. Contributions are welcome — bug reports, fixes, and new tools alike. STINT is maintained in spare time, so replies may take a few days.

## Before you start

- **Bugs:** open an issue with your macOS version, what you did, what you expected, and what happened. Screenshots help; please blur or crop out your network details (IP addresses, Wi-Fi names, MAC addresses) first.
- **Bigger changes** (a new tool, a redesign, a new dependency): open an issue first so we can agree on the approach before you spend time on it.
- **Security issues:** don't open a public issue. See [SECURITY.md](SECURITY.md).

## Building

Requirements: macOS 13 or later and Xcode 15 or later (Xcode 26 or later for the Liquid Glass styling).

```bash
git clone https://github.com/Sevoog/STINT.git
cd STINT
open STINT.xcodeproj    # ⌘R to run, ⌘U to run the tests
```

Or from the command line:

```bash
xcodebuild -project STINT.xcodeproj -scheme STINT test
```

## Guidelines

- **No third-party dependencies.** STINT uses only Apple's frameworks. If you think a dependency is truly needed, raise it in an issue first.
- **Match the surrounding code:** its naming, comment style, and structure. New tools are added to the `Tool` enum in `ContentView.swift`; simple "address in, command output out" tools can reuse `AddressCommandTool`.
- **Keep the build clean.** No new compiler warnings, and all tests pass. Add tests in `STINTTests` for logic that can be tested without the UI, such as parsers.
- **Privacy is a feature.** STINT makes no network requests on its own; it only contacts the hosts you point a tool at. If your change contacts a new host or service, runs a new system tool, or stores new data, add it to the Privacy & Security section of [README.md](README.md). No analytics or telemetry.
- **Screenshots:** if you change how a tool looks, you can regenerate the README screenshots with `marketing/render.sh` and `marketing/build.py`.
- **Update the CHANGELOG.** Add a short entry under `[Unreleased]` in [CHANGELOG.md](CHANGELOG.md).

## Contributor License Agreement

Before your first pull request can be merged, you'll need to sign the [Contributor License Agreement](CLA.md). The CLA Assistant bot will prompt you on the pull request; you sign by posting a comment. It takes a minute and covers all your future contributions.

**Why a CLA?** STINT is licensed under the GPL v3, and may also be offered under other licenses, including commercial ones, for organizations that can't use GPL software. The CLA lets the maintainer include your contribution in those versions too. You keep the copyright in your work, and anything released under the GPL stays available under the GPL.

## License

By contributing, you agree that your contributions are licensed under the [GNU GPL v3](LICENSE) and the terms of the [CLA](CLA.md).
