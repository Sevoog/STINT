# Changelog

All notable changes to STINT are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- **Pings no longer run forever in the background.** An unlimited ping kept running after
  you switched tabs, closed the window, or even quit STINT. Running commands now stop when
  you leave the tool or quit the app. An invalid ping count no longer silently starts an
  unlimited ping.
- **Stopping and restarting a command** no longer leaves the UI saying it has finished while
  the new run is still going.
- **Port Scan crash risk.** Two threads could both report a result for the same port, which
  can crash the app. Closed ports are now detected immediately instead of waiting out the
  one-second timeout, so scans are much faster (3,000 ports in about a second on localhost).
  Leaving the Port Scan or Bonjour tab now stops the scan or browse.
- **Info tab shows the real adapter names** that System Settings uses (for example
  "Thunderbolt Ethernet Slot 0") instead of guessing from `en0`/`en1`, plus the vendor and
  model the hardware reports. Link speeds of 2.5, 5 and 10 Gbps are recognized, and transfer
  statistics are correct for loopback and VPN interfaces.
- **Menu bar widget:** "Open STINT" reopens the main window after it's been closed; the
  network monitor is no longer duplicated every time the menu opens; the IP shown is the
  Wi-Fi or Ethernet address carrying traffic (not a VPN or virtual-machine address) and
  updates when the network changes; a timed-out quick ping shows in red.
- Fixed a possible crash when reading network interfaces that have no address.

### Added
- **Local Network permission support (macOS 15+).** The permission prompt now explains why
  STINT needs access, and Bonjour and Port Scan say so when access is denied instead of
  silently finding nothing.
- Copyright notice in the app's About panel.

### Changed
- The Settings → About version number now comes from the app bundle instead of being
  hard-coded.

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
