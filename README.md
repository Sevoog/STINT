# STINT

**Sev's Tiny Internet Network Tool** — A modern macOS network utility app inspired by Apple's classic Network Utility that was deprecated after macOS Monterey. Built with SwiftUI for both Intel and Apple Silicon Macs.

Free and open source under the [GNU GPL v3](LICENSE). No accounts, analytics, telemetry, or crash reporting. See [Privacy](#privacy) for what STINT contacts and stores.

If STINT is useful to you, you can [buy me a coffee](https://buymeacoffee.com/sevoog).

## Screenshots

![Ping: a live latency chart with current, min, avg, max and loss](marketing/screenshots/framed/01-ping.png)
![Info: addresses, link speed, vendor and model for each network adapter](marketing/screenshots/framed/02-info.png)
![Port Scan: common TCP services or any range](marketing/screenshots/framed/03-port-scan.png)
![Menu bar widget: connection status, local IP and a quick ping](marketing/screenshots/framed/04-menu-bar.png)

<details>
<summary>More screenshots</summary>

![Traceroute: every hop to a host](marketing/screenshots/framed/05-traceroute.png)
![Lookup: DNS records of any type](marketing/screenshots/framed/06-lookup.png)
![Bonjour: services announced on your network](marketing/screenshots/framed/07-bonjour.png)

</details>

*Screenshots use placeholder demo data; no real network details are shown.*

## Install

1. Download the latest **STINT-x.y.z.zip** from [Releases](https://github.com/Sevoog/STINT/releases/latest).
2. Unzip it and drag **STINT** into your **Applications** folder.
3. Open STINT. Because STINT isn't notarized by Apple, the first time you open it macOS says Apple could not verify that it is free of malware. Click **Done**.
4. Open **System Settings → Privacy & Security** and scroll down to **Security**. Next to the message that STINT was blocked, click **Open Anyway**, and enter your password if asked.
5. Click **Open Anyway** in the confirmation that appears. From then on, STINT opens normally.

You'll repeat steps 3–5 each time you install a new version. On macOS 13 and 14 you can instead Control-click STINT in Applications, choose **Open**, then click **Open**.

To check your download, compare its checksum with the one listed on the release page:

```bash
shasum -a 256 ~/Downloads/STINT-*.zip
```

## Features

- **Info** - View network interface information (IP address, MAC address, link status, transfer statistics)
- **Netstat** - Display routing tables, network statistics, multicast info, and socket states
- **Ping** - Ping network hosts with configurable count or unlimited mode, with a live latency chart (Swift Charts) and Chart/Text toggle
- **Lookup** - DNS lookups with support for various record types (A, AAAA, MX, NS, TXT, etc.)
- **Traceroute** - Trace the route to a network host
- **Whois** - Look up domain registration information
- **Finger** - Query finger protocol servers (legacy)
- **Port Scan** - Scan hosts for open TCP ports
- **Bonjour** - Browse for mDNS/Bonjour services on your local network

### Additional Features

- **Export Results** - Export any results to TXT, CSV, or JSON format
- **Menu Bar Widget** - Quick access to network status, IP address, and ping tests from the menu bar
- **Settings** - Configurable preferences for default values and behavior
- **macOS 26 Liquid Glass** - Automatically adopts the new Liquid Glass design when running on macOS Tahoe

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later (Xcode 26 for Liquid Glass support)

## Building

### Option 1: Using Xcode

1. Open `STINT.xcodeproj` in Xcode
2. Select your development team in Signing & Capabilities (or disable signing for local use)
3. Build and run (Cmd+R)

### Option 2: Command Line

```bash
# Build for both Intel and Apple Silicon (Universal Binary)
xcodebuild -project STINT.xcodeproj \
  -scheme STINT \
  -configuration Release \
  -arch x86_64 -arch arm64 \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY="-" \
  build

# The app will be in build/Release/STINT.app
```

## Menu Bar Widget

STINT includes a menu bar widget that provides:
- Network connection status indicator
- Current local IP address display
- Quick ping buttons (8.8.8.8, 1.1.1.1, apple.com)
- Copy IP address to clipboard
- Quick access to open the main window

Toggle the menu bar icon visibility via View > Show Menu Bar Icon (Cmd+Shift+M).

## Export Functionality

Results from every tool can be exported:
- Click the Export button next to the action button
- Choose format: Plain Text, CSV, or JSON
- Save to a custom location or quick-export to Downloads

## Permissions

The app requires network access to function. Since it uses system networking commands (`ping`, `traceroute`, `netstat`, etc.), it runs without app sandbox restrictions.

For full functionality, you may need to:
- Approve STINT the first time you open it, because it isn't notarized by Apple (see [Install](#install))
- Allow **Local Network** access when prompted (macOS 15 and later). Bonjour browsing and port scans of devices on your network need it; you can change it later in System Settings > Privacy & Security > Local Network

## macOS 26 Liquid Glass

When compiled with Xcode 26 and running on macOS Tahoe (26), STINT's control layer adopts the new Liquid Glass design language: the tool action buttons use the system `.glass` button style, and the window and menu-bar chrome inherit the glass material from the macOS 26 SDK. The selected tab is a refined accent-colored capsule. Output/results panels intentionally stay solid for readability, following Apple's Human Interface Guidelines (glass is for the control and navigation layer, not content-heavy areas).

The Liquid Glass styling is gated behind an availability check, so on macOS 13–15 the app keeps its previous appearance and continues to build against the macOS 13 deployment target.

## Notes

- The Port Scan feature uses native Swift networking (NWConnection) for efficiency
- The Bonjour browser uses NWBrowser for native service discovery
- Most network operations run asynchronously and can be stopped mid-execution
- The Finger protocol is largely deprecated but included for completeness
- Some operations (like traceroute) may require running the app with elevated privileges for full functionality

## Privacy

STINT has no accounts, analytics, telemetry, or crash reporting, and makes no network requests on its own.

- **Network traffic** goes only to the hosts you point a tool at, plus 8.8.8.8, 1.1.1.1 or apple.com when you click a quick-ping button in the menu bar. DNS lookups use your Mac's configured DNS servers, and Whois asks the public whois servers for the domain you look up. Bonjour listens for services announced on your local network.
- **Stored data** is limited to STINT's settings (default ping host and count, menu bar icon, launch at login).
- **Exports** are written only where you choose, or to your Downloads folder with Quick Export.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for the full release history.

## Author

Created by Sevag Bardakjian

## Contributing

Bug reports and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for how to build, and the [Contributor License Agreement](CLA.md) you'll be asked to sign on your first pull request. Please report security issues privately; see [SECURITY.md](SECURITY.md).

## License

STINT is free software, licensed under the [GNU General Public License v3.0](LICENSE) (`GPL-3.0-only`). You can use, study, change, and share it. If you distribute a modified version, you must release its source code under the same license.

STINT comes with **absolutely no warranty**. Copyright © 2026 Sevag Bardakjian.

If you'd like to use STINT under terms other than the GPL, for example in a closed-source product, open an issue or get in touch through GitHub.
