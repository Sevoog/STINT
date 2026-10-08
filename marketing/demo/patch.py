# Screenshot-only edits to throwaway copies of STINT's sources (see ../render.sh).
# They feed the real views placeholder data and run each tool as it appears, so the
# screenshots show no real network details and the app itself carries no demo mode.
#
# Each edit must match exactly once; if the app's code changes, this fails loudly
# instead of producing a wrong screenshot.
import pathlib
import random
import sys

src = pathlib.Path(sys.argv[1])


def patch(fname, old, new):
    p = src / fname
    t = p.read_text()
    assert t.count(old) == 1, f"{fname}: expected one match for {old!r}, found {t.count(old)}"
    p.write_text(t.replace(old, new))


patch("STINTApp.swift", "@main\n", "")
patch("ContentView.swift", "@State private var selectedTool: Tool = .info", "@State var selectedTool: Tool = .info")
patch("CommandRunner.swift", "        stop()\n        \n        isRunning = true",
      "        stop()\n        if let demo = DemoData.output(for: command) { output = demo; isRunning = false; return }\n        \n        isRunning = true")
patch("PingView.swift", "@State private var showChart: Bool = false", "@State private var showChart: Bool = true")
patch("PingView.swift", "if pingCount.isEmpty { pingCount = String(defaultPingCount) }",
      "if pingCount.isEmpty { pingCount = String(defaultPingCount) }\n            runPing()")
patch("Styles.swift", "        .onDisappear { runner.stop() }",
      "        .onAppear { if let demo = DemoData.address[exportPrefix] { address = demo; run() } }\n        .onDisappear { runner.stop() }")
# Liquid Glass and the active-window button tint don't render offscreen; draw the
# prominent action button as the accent capsule it looks like on screen.
patch("Styles.swift", "self.buttonStyle(.glassProminent)", "self.buttonStyle(DemoGlassProminent())")
patch("LookupView.swift", "        .onDisappear { runner.stop() }",
      "        .onAppear { address = \"apple.com\"; lookupType = 5; runLookup() }\n        .onDisappear { runner.stop() }")
patch("PortScanView.swift", '@State private var address: String = ""', '@State private var address: String = "192.168.1.20"')
patch("PortScanView.swift", '@State private var output: String = ""', '@State private var output: String = DemoData.portScan')
patch("InfoView.swift", "let loaded = loadAllInterfaces()", "let loaded = DemoData.interfaces")
patch("InfoView.swift", "let newStats = fetchPacketStats(for: interface)", "let newStats = DemoData.stats")
patch("BonjourView.swift", "@Published var services: [BonjourService] = []", "@Published var services: [BonjourService] = DemoData.bonjour")
patch("BonjourView.swift", '@Published var statusMessage = ""', '@Published var statusMessage = "Found \\(DemoData.bonjour.count) services"')
patch("BonjourView.swift", "@State private var browseAllTypes = false", "@State private var browseAllTypes = true")
patch("MenuBarWidget.swift", 'let ip = localIPv4Address(for: path) ?? "Not available"', 'let ip = "192.168.1.50"')
patch("MenuBarWidget.swift", '@State private var pingResult = ""', '@State private var pingResult = "11.8 ms"')

# A placeholder ping run: steady ~12 ms with one spike (amber) and one lost packet (red).
random.seed(7)
lines = ["PING 1.1.1.1 (1.1.1.1): 56 data bytes"]
latencies = []
for seq in range(40):
    if seq == 23:
        lines.append(f"Request timeout for icmp_seq {seq}")
        continue
    ms = 38.2 if seq == 14 else round(random.uniform(10.6, 14.9) + (2.5 if 30 <= seq <= 33 else 0), 3)
    latencies.append(ms)
    lines.append(f"64 bytes from 1.1.1.1: icmp_seq={seq} ttl=57 time={ms:.3f} ms")
lines += ["", "--- 1.1.1.1 ping statistics ---",
          f"40 packets transmitted, {len(latencies)} packets received, 2.5% packet loss",
          f"round-trip min/avg/max/stddev = {min(latencies):.3f}/{sum(latencies) / len(latencies):.3f}/{max(latencies):.3f}/4.512 ms"]
ping = "\\n".join(lines) + "\\n"

(src / "DemoData.swift").write_text(f'''import SwiftUI

// Placeholder data for screenshots: private LAN addresses, RFC 5737 documentation
// addresses for the internet, and a dummy MAC address.
enum DemoData {{
    static let address: [String: String] = ["Traceroute": "1.1.1.1", "Whois": "example.com"]

    static func output(for command: String) -> String? {{
        switch command {{
        case "/sbin/ping": return ping
        case "/usr/sbin/traceroute": return traceroute
        case "/usr/bin/nslookup": return lookup
        default: return nil
        }}
    }}

    static let ping = "{ping}"

    static let traceroute = """
    traceroute to 1.1.1.1 (1.1.1.1), 64 hops max, 40 byte packets
     1  router.lan (192.168.1.1)  1.912 ms  1.204 ms  1.188 ms
     2  203.0.113.1 (203.0.113.1)  8.733 ms  7.902 ms  8.115 ms
     3  ae-12.core1.example.net (198.51.100.17)  9.410 ms  9.207 ms  10.002 ms
     4  ae-3.edge2.example.net (198.51.100.42)  10.876 ms  11.031 ms  10.654 ms
     5  * * *
     6  peer.cloudflare.example (198.51.100.97)  11.120 ms  11.344 ms  10.987 ms
     7  one.one.one.one (1.1.1.1)  11.402 ms  11.198 ms  11.360 ms

    """

    static let lookup = """
    Server:\\t\\t1.1.1.1
    Address:\\t1.1.1.1#53

    Non-authoritative answer:
    apple.com\\tmail exchanger = 10 mx-in.g.apple.com.
    apple.com\\tmail exchanger = 20 mx-in-hfd.apple.com.
    apple.com\\tmail exchanger = 20 mx-in-ma.apple.com.
    apple.com\\tmail exchanger = 20 mx-in-mdn.apple.com.
    apple.com\\tmail exchanger = 20 mx-in-rno.apple.com.
    apple.com\\tmail exchanger = 20 mx-in-sg.apple.com.
    apple.com\\tmail exchanger = 20 mx-in-vib.apple.com.

    Authoritative answers can be found from:

    """

    static let portScan = """
    Port Scan has started...

    Scanning 192.168.1.20 (30 ports)...

    Port 22 (ssh) is open
    Port 80 (http) is open
    Port 443 (https) is open
    Port 445 (microsoft-ds) is open
    Port 5900 (vnc) is open

    --- Port scan complete ---
    Open ports found: 5

    """

    static let interfaces: [NetworkInterface] = [
        NetworkInterface(id: "en0", name: "en0", displayName: "en0 (Ethernet)", hardwareAddress: "de:ad:be:ef:ca:fe",
                         ipAddress: "192.168.1.50", ipv6Address: "fe80::1c2b:3d4e:5f60:7a8b%en0", linkSpeed: "10 Gbps",
                         linkStatus: "Active", vendor: "Aquantia", model: "AQC113"),
        NetworkInterface(id: "en1", name: "en1", displayName: "en1 (Wi-Fi)", hardwareAddress: "de:ad:be:ef:ca:01",
                         ipAddress: "", ipv6Address: "", linkSpeed: "N/A", linkStatus: "Inactive", vendor: "Apple", model: "Wi-Fi Adapter"),
        NetworkInterface(id: "lo0", name: "lo0", displayName: "lo0 (Loopback)", hardwareAddress: "N/A",
                         ipAddress: "127.0.0.1", ipv6Address: "::1", linkSpeed: "N/A", linkStatus: "Unknown", vendor: "N/A", model: "Loopback"),
    ]
    static let stats = (sent: "48213577", received: "71904233", sendErrors: "0", recvErrors: "0", collisions: "0")

    static let bonjour: [BonjourService] = [
        BonjourService(name: "Living Room", type: "_airplay._tcp", domain: "local."),
        BonjourService(name: "Kitchen HomePod", type: "_raop._tcp", domain: "local."),
        BonjourService(name: "Office LaserJet", type: "_ipp._tcp", domain: "local."),
        BonjourService(name: "Office LaserJet", type: "_printer._tcp", domain: "local."),
        BonjourService(name: "Studio Mac", type: "_ssh._tcp", domain: "local."),
        BonjourService(name: "Studio Mac", type: "_rfb._tcp", domain: "local."),
        BonjourService(name: "NAS", type: "_smb._tcp", domain: "local."),
        BonjourService(name: "NAS", type: "_adisk._tcp", domain: "local."),
        BonjourService(name: "NAS Web UI", type: "_http._tcp", domain: "local."),
        BonjourService(name: "Hue Bridge", type: "_hap._tcp", domain: "local."),
        BonjourService(name: "Bedroom TV", type: "_googlecast._tcp", domain: "local."),
    ].sorted {{ $0.name.lowercased() < $1.name.lowercased() }}
}}

// Stand-in for .glassProminent: a filled accent capsule.
struct DemoGlassProminent: ButtonStyle {{
    func makeBody(configuration: Configuration) -> some View {{
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.accentColor))
    }}
}}
''')
