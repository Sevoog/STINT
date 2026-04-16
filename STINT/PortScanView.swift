import SwiftUI
import Network

struct PortScanView: View {
    @State private var address: String = ""
    @State private var onlyTestPorts: Bool = true
    @State private var startPort: String = "1"
    @State private var endPort: String = "1024"
    @State private var output: String = ""
    @State private var isScanning: Bool = false
    @State private var scanTask: Task<Void, Never>?
    
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
                
                Button(action: runScan) {
                    Text("Scan")
                        .frame(width: 50)
                }
                .disabled(address.isEmpty || isScanning)
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding(.horizontal, 20)
            
            // Output area
            ScrollingOutputArea(text: output, placeholder: "Enter an address and click Scan.")
                .padding(.horizontal, 20)
            
            if isScanning {
                StatusRow(isRunning: true, message: "Port scan in progress...") {
                    stopScan()
                }
            } else {
                Spacer().frame(height: 32)
            }
        }
        .padding(.bottom, 12)
    }
    
    private func runScan() {
        isScanning = true
        output = "Port Scan has started...\n\n"
        
        let portsToScan: [Int]
        
        if onlyTestPorts {
            // Common TCP ports
            portsToScan = [
                20, 21, 22, 23, 25, 53, 80, 110, 119, 123, 143, 161, 194,
                443, 445, 465, 514, 587, 993, 995, 1433, 1521, 3306, 3389,
                5432, 5900, 6379, 8080, 8443, 27017
            ]
        } else {
            let start = Int(startPort) ?? 1
            let end = Int(endPort) ?? 1024
            portsToScan = Array(start...min(end, 65535))
        }
        
        let targetAddress = address
        
        scanTask = Task {
            output += "Scanning \(targetAddress) for open ports...\n\n"
            
            var openPorts: [Int] = []
            
            for port in portsToScan {
                if Task.isCancelled { break }
                
                let isOpen = await checkPort(host: targetAddress, port: port)
                
                if isOpen {
                    let serviceName = getServiceName(for: port)
                    let portInfo = "Port \(port) (\(serviceName)) is open\n"
                    await MainActor.run {
                        output += portInfo
                    }
                    openPorts.append(port)
                }
            }
            
            await MainActor.run {
                if !Task.isCancelled {
                    output += "\n--- Port scan complete ---\n"
                    output += "Open ports found: \(openPorts.count)\n"
                }
                isScanning = false
            }
        }
    }
    
    private func stopScan() {
        scanTask?.cancel()
        isScanning = false
        output += "\n--- Port scan stopped ---\n"
    }
    
    private func checkPort(host: String, port: Int) async -> Bool {
        return await withCheckedContinuation { continuation in
            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(integerLiteral: UInt16(port)),
                using: .tcp
            )
            
            var resumed = false
            let resumeOnce: (Bool) -> Void = { result in
                if !resumed {
                    resumed = true
                    continuation.resume(returning: result)
                }
            }
            
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.cancel()
                    resumeOnce(true)
                case .failed, .cancelled:
                    resumeOnce(false)
                default:
                    break
                }
            }
            
            connection.start(queue: .global())
            
            // Timeout after 1 second
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                connection.cancel()
                resumeOnce(false)
            }
        }
    }
    
    private func getServiceName(for port: Int) -> String {
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
}

#Preview {
    PortScanView()
}
