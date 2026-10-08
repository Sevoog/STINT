import SwiftUI
import Network

// Menu bar extra for quick network actions
struct MenuBarWidget: View {
    @State private var pingResult = ""
    @State private var isPinging = false
    @State private var currentIP = "Checking..."
    @State private var connectionStatus = "Unknown"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "globe")
                    .foregroundColor(.accentColor)
                Text("STINT")
                    .font(.headline)
                Spacer()
            }
            .padding(.bottom, 4)
            
            Divider()
            
            // Network status
            VStack(alignment: .leading, spacing: 4) {
                Label {
                    Text("Status: \(connectionStatus)")
                        .font(.system(size: 12))
                } icon: {
                    Circle()
                        .fill(connectionStatus == "Connected" ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                }
                
                Text("IP: \(currentIP)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
            
            Divider()
            
            // Quick ping
            HStack {
                Text("Quick Ping:")
                    .font(.system(size: 12))
                Spacer()
                if isPinging {
                    ProgressView()
                        .scaleEffect(0.6)
                } else {
                    Text(pingResult.isEmpty ? "-" : pingResult)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(pingResult.contains("error") ? .red : .green)
                }
            }
            
            HStack(spacing: 8) {
                Button("8.8.8.8") {
                    quickPing("8.8.8.8")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .glassActionButton()
                
                Button("1.1.1.1") {
                    quickPing("1.1.1.1")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .glassActionButton()
                
                Button("apple.com") {
                    quickPing("apple.com")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .glassActionButton()
            }
            
            Divider()
            
            // Quick actions
            Button(action: openMainWindow) {
                Label("Open STINT", systemImage: "rectangle.expand.vertical")
            }
            .buttonStyle(.plain)
            
            Button(action: copyIPToClipboard) {
                Label("Copy IP Address", systemImage: "doc.on.doc")
            }
            .buttonStyle(.plain)
            .disabled(currentIP == "Checking..." || currentIP == "Not available")
            
            Divider()
            
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Label("Quit STINT", systemImage: "power")
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(width: 240)
        .onAppear {
            checkNetworkStatus()
            fetchCurrentIP()
        }
    }
    
    private func quickPing(_ host: String) {
        isPinging = true
        pingResult = ""
        
        Task {
            let result = await performQuickPing(host)
            await MainActor.run {
                pingResult = result
                isPinging = false
            }
        }
    }
    
    private func performQuickPing(_ host: String) async -> String {
        return await withCheckedContinuation { continuation in
            let process = Process()
            let pipe = Pipe()
            
            process.executableURL = URL(fileURLWithPath: "/sbin/ping")
            process.arguments = ["-c", "1", "-t", "2", host]
            process.standardOutput = pipe
            process.standardError = pipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    // Extract time from ping output
                    if let range = output.range(of: "time=") {
                        let timeStart = output[range.upperBound...]
                        if let endRange = timeStart.range(of: " ms") ?? timeStart.range(of: "ms") {
                            let time = String(timeStart[..<endRange.lowerBound])
                            continuation.resume(returning: "\(time) ms")
                            return
                        }
                    }
                    if output.contains("Request timeout") || output.contains("100.0% packet loss") {
                        continuation.resume(returning: "timeout")
                        return
                    }
                }
                continuation.resume(returning: "error")
            } catch {
                continuation.resume(returning: "error")
            }
        }
    }
    
    private func checkNetworkStatus() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                if path.status == .satisfied {
                    connectionStatus = "Connected"
                } else {
                    connectionStatus = "Disconnected"
                }
            }
        }
        monitor.start(queue: DispatchQueue.global(qos: .background))
    }
    
    private func fetchCurrentIP() {
        // Get local IP from network interfaces
        var address: String = "Not available"
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                
                let interface = ptr?.pointee
                let addrFamily = interface?.ifa_addr.pointee.sa_family
                
                if addrFamily == UInt8(AF_INET) {
                    let name = String(cString: (interface?.ifa_name)!)
                    // Skip loopback
                    if name != "lo0" {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface?.ifa_addr, socklen_t((interface?.ifa_addr.pointee.sa_len)!),
                                    &hostname, socklen_t(hostname.count),
                                    nil, socklen_t(0), NI_NUMERICHOST)
                        let ip = String(cString: hostname)
                        if !ip.isEmpty && !ip.hasPrefix("127.") {
                            address = ip
                            break
                        }
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        
        currentIP = address
    }
    
    private func openMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        // Bring the main app window forward, skipping the menu bar popover and other panels
        if let window = NSApplication.shared.windows.first(where: { $0.canBecomeMain && $0.styleMask.contains(.titled) }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    private func copyIPToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(currentIP, forType: .string)
    }
}

#Preview {
    MenuBarWidget()
}
