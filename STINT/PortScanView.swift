import SwiftUI
import Network

private let commonPorts: [Int] = [
    20, 21, 22, 23, 25, 53, 80, 110, 119, 123, 143, 161, 194,
    443, 445, 465, 514, 587, 993, 995, 1433, 1521, 3306, 3389,
    5432, 5900, 6379, 8080, 8443, 27017
]

struct PortScanView: View {
    @State private var address: String = ""
    @State private var onlyTestPorts: Bool = true
    @State private var startPort: String = "1"
    @State private var endPort: String = "1024"
    @State private var output: String = ""
    @State private var isScanning: Bool = false
    @State private var scanTask: Task<Void, Never>?
    @State private var scannedCount: Int = 0
    @State private var totalToScan: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Enter the internet address to scan for open ports.")
                .font(.system(size: 12))
                .padding(.top, 16)
                .padding(.horizontal, 20)

            HStack {
                TextField("", text: $address)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 250)

                Text("(ex. 10.0.2.1 or www.example.com)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding(.horizontal, 20)

            RadioButton(title: "Only test ports commonly used by TCP services", isSelected: onlyTestPorts) {
                onlyTestPorts = true
            }
            .padding(.horizontal, 20)

            HStack(spacing: 8) {
                RadioButton(title: "Only test ports between", isSelected: !onlyTestPorts) {
                    onlyTestPorts = false
                }

                TextField("", text: $startPort)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .disabled(onlyTestPorts)

                Text("and")
                    .font(.system(size: 12))

                TextField("", text: $endPort)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .disabled(onlyTestPorts)

                Spacer()

                ExportButton(
                    title: "PortScan_\(address.isEmpty ? "results" : address)",
                    output: output,
                    command: portScanCommandDescription()
                )

                Button(action: runScan) {
                    Text("Scan")
                        .frame(width: 50)
                }
                .disabled(address.isEmpty || isScanning)
                .keyboardShortcut(.return, modifiers: [])
                .glassActionButton()
            }
            .padding(.horizontal, 20)

            ScrollingOutputArea(text: output, placeholder: "Enter an address and click Scan.")
                .padding(.horizontal, 20)

            if isScanning {
                StatusRow(isRunning: true, message: "Port scan in progress... \(scannedCount)/\(totalToScan)") {
                    stopScan()
                }
            } else {
                Spacer().frame(height: 32)
            }
        }
        .padding(.bottom, 12)
        .onDisappear { scanTask?.cancel() }
    }

    private func runScan() {
        let portsToScan: [Int]
        if onlyTestPorts {
            portsToScan = commonPorts
        } else {
            let start = max(1, Int(startPort) ?? 1)
            let end = Int(endPort) ?? 1024
            portsToScan = start <= end ? Array(start...min(end, 65535)) : []
        }

        guard !portsToScan.isEmpty else {
            output = "Invalid port range.\n"
            return
        }

        isScanning = true
        output = "Port Scan has started...\n\n"
        scannedCount = 0
        totalToScan = portsToScan.count

        let targetAddress = address

        scanTask = Task {
            await MainActor.run {
                output += "Scanning \(targetAddress) (\(portsToScan.count) ports)...\n\n"
            }

            let (openPorts, deniedCount) = await scanPorts(host: targetAddress, ports: portsToScan)

            await MainActor.run {
                // A stopped scan has already reset the UI, and a new scan may be running;
                // only a scan that ran to completion reports results.
                guard !Task.isCancelled else { return }
                for port in openPorts.sorted() {
                    output += "Port \(port) (\(serviceName(for: port))) is open\n"
                }
                if deniedCount > 0 {
                    output += "\nmacOS blocked \(deniedCount) connection\(deniedCount == 1 ? "" : "s") because STINT "
                    output += "doesn't have Local Network access. Turn it on in System Settings → "
                    output += "Privacy & Security → Local Network, then scan again.\n"
                }
                output += "\n--- Port scan complete ---\n"
                output += "Open ports found: \(openPorts.count)\n"
                isScanning = false
            }
        }
    }

    // Scan ports concurrently with a bounded number of in-flight connections.
    // Returns the open ports and how many probes macOS blocked for lack of Local Network access.
    private func scanPorts(host: String, ports: [Int]) async -> (open: [Int], denied: Int) {
        let maxConcurrent = 64
        var openPorts: [Int] = []
        var deniedCount = 0

        await withTaskGroup(of: (Int, PortState).self) { group in
            var index = 0

            for _ in 0..<min(maxConcurrent, ports.count) {
                let port = ports[index]
                index += 1
                group.addTask { (port, await checkPort(host: host, port: port)) }
            }

            while let (port, state) = await group.next() {
                switch state {
                case .open: openPorts.append(port)
                case .localNetworkDenied: deniedCount += 1
                case .closed: break
                }
                await MainActor.run { scannedCount += 1 }

                if Task.isCancelled {
                    group.cancelAll()
                    break
                }

                if index < ports.count {
                    let next = ports[index]
                    index += 1
                    group.addTask { (next, await checkPort(host: host, port: next)) }
                }
            }
        }

        return (openPorts, deniedCount)
    }

    private func stopScan() {
        scanTask?.cancel()
        isScanning = false
        output += "\n--- Port scan stopped ---\n"
    }

    private func portScanCommandDescription() -> String {
        if onlyTestPorts {
            return "portscan \(address) (common TCP ports)"
        }
        return "portscan \(address) ports \(startPort)-\(endPort)"
    }
}

private enum PortState {
    case open, closed, localNetworkDenied
}

private func checkPort(host: String, port: Int) async -> PortState {
    return await withCheckedContinuation { continuation in
        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(integerLiteral: UInt16(port)),
            using: .tcp
        )

        // The state handler and the timeout both run on this serial queue, so `resumed`
        // is never read and written concurrently. Resuming a continuation twice crashes.
        let queue = DispatchQueue(label: "com.sevag.stint.portscan")
        var resumed = false
        let finish: (PortState) -> Void = { result in
            guard !resumed else { return }
            resumed = true
            connection.cancel()
            continuation.resume(returning: result)
        }

        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                finish(.open)
            case .waiting:
                // A refused connection waits for a retry rather than failing outright.
                // It's not going to open, and it may be macOS blocking local network access.
                finish(connection.currentPath?.unsatisfiedReason == .localNetworkDenied ? .localNetworkDenied : .closed)
            case .failed, .cancelled:
                finish(.closed)
            default:
                break
            }
        }

        connection.start(queue: queue)

        // Timeout after 1 second
        queue.asyncAfter(deadline: .now() + 1.0) {
            finish(.closed)
        }
    }
}

private func serviceName(for port: Int) -> String {
    let services: [Int: String] = [
        20: "ftp-data",
        21: "ftp",
        22: "ssh",
        23: "telnet",
        25: "smtp",
        53: "dns",
        80: "http",
        110: "pop3",
        119: "nntp",
        123: "ntp",
        143: "imap",
        161: "snmp",
        194: "irc",
        443: "https",
        445: "microsoft-ds",
        465: "smtps",
        514: "syslog",
        587: "submission",
        993: "imaps",
        995: "pop3s",
        1433: "mssql",
        1521: "oracle",
        3306: "mysql",
        3389: "rdp",
        5432: "postgresql",
        5900: "vnc",
        6379: "redis",
        8080: "http-proxy",
        8443: "https-alt",
        27017: "mongodb"
    ]
    return services[port] ?? "unknown"
}

#Preview {
    PortScanView()
}
