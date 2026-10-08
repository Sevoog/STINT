# Changelog

All notable changes to STINT are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.0] - 2026-05-26

### Added
- **Live Ping latency chart.** The Ping tool can now display results as a live, native
  Swift Charts latency graph instead of (or alongside) the raw text. A **Chart / Text**
  segmented toggle switches between the two; the chart streams a new point per reply,
  highlights latency spikes in amber and lost packets in red, and is topped by glanceable
  Current / Min / Avg / Max / Loss summary tiles.

## [1.2.0] - 2026-05-25

### Added
- **Liquid Glass theme.** On macOS 26 (Tahoe) the tool action buttons adopt the native
  Liquid Glass material via the system `.glass` button style, and the app inherits glass
  window/menu-bar chrome from the macOS 26 SDK. Output panels remain solid for legibility,
  per Apple's Human Interface Guidelines (glass belongs on the control layer, not content).
- A defined **accent color** (system blue, with a dark-mode variant) — previously the
  `AccentColor` asset was empty, leaving the accent undefined.

### Changed
- The selected tab is now a refined accent-colored capsule with a legible label (replacing
  the old flat rounded rectangle). Glass-on-tabs was evaluated but dropped: in dark mode the
  glass material was too faint to serve as the primary selection indicator and hurt contrast.
- Liquid Glass button styling is gated behind `if #available(macOS 26.0, *)`, so older
  systems keep the previous appearance and the macOS 13 deployment target still builds.

## [1.1.0] - 2026-05-25

### Fixed
- **Settings now apply.** "Default Ping Host" and "Default Ping Count" actually seed
  the Ping tool; previously the fields were hardcoded and the settings did nothing.
- **"Launch at Login" works.** It is now wired to `SMAppService` (register/unregister)
  and synced to the real system state, instead of being a no-op toggle.
- **Unified menu bar icon setting.** The View menu toggle, the Settings toggle, and the
  actual menu bar visibility now share one persisted value and no longer reset on launch.
- **Menu bar "Open STINT"** reliably brings the main window forward instead of matching
  an arbitrary window.
- **Port Scan is dramatically faster.** Ports are now scanned concurrently (bounded at
  64 in flight) with a live progress counter; large ranges finish in seconds instead of
  minutes, and invalid ranges are guarded.
- Removed leftover "Packetry" labels from the menu bar widget.

### Added
- **Export everywhere.** TXT / CSV / JSON export is now available on every tool —
  Netstat, Lookup, Whois, Finger, Port Scan, and Bonjour — not just Ping and Traceroute.

### Changed
- _Internal:_ tab navigation is data-driven via a `Tool` enum instead of hand-numbered
  indices, so adding or reordering a tool is a one-line change.
- _Internal:_ the simple command tools (Whois, Finger, Traceroute) now share a single
  `AddressCommandTool` view, removing duplicated boilerplate.

## [1.0.0]

- Initial release: Info, Netstat, Ping, Lookup, Traceroute, Whois, Finger, Port Scan,
  and Bonjour tools; menu bar widget; export for Ping and Traceroute.
