# STINT

**Sev's Tiny Internet Network Tool** — A modern macOS network utility app inspired by Apple's classic Network Utility that was deprecated after macOS Monterey. Built with SwiftUI for both Intel and Apple Silicon Macs.

## Features

- **Info** - View network interface information (IP address, MAC address, link status, transfer statistics)
- **Netstat** - Display routing tables, network statistics, multicast info, and socket states
- **Ping** - Ping network hosts with configurable count or unlimited mode
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

Results from Ping, Traceroute, and other tools can be exported:
- Click the Export button next to the action button
- Choose format: Plain Text, CSV, or JSON
- Save to a custom location or quick-export to Downloads

## Permissions

The app requires network access to function. Since it uses system networking commands (`ping`, `traceroute`, `netstat`, etc.), it runs without app sandbox restrictions.

For full functionality, you may need to:
- Allow the app in System Settings > Privacy & Security if macOS blocks it
- Grant terminal/network permissions if prompted

## macOS 26 Liquid Glass

When compiled with Xcode 26 and running on macOS Tahoe (26), the app automatically adopts the new Liquid Glass design language. Standard SwiftUI controls, toolbars, and navigation elements will display with the translucent, light-bending Liquid Glass material.

## Notes

- The Port Scan feature uses native Swift networking (NWConnection) for efficiency
- The Bonjour browser uses NWBrowser for native service discovery
- Most network operations run asynchronously and can be stopped mid-execution
- The Finger protocol is largely deprecated but included for completeness
- Some operations (like traceroute) may require running the app with elevated privileges for full functionality

## Author

Created by Sevag Bardakjian

## License

This is an open-source project. Use at your own risk.
