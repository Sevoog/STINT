import SwiftUI
import Network
import SystemConfiguration

struct NetworkInterface: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let displayName: String
    let hardwareAddress: String
    let ipAddress: String
    let ipv6Address: String
    let linkSpeed: String
    let linkStatus: String
    let vendor: String
    let model: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: NetworkInterface, rhs: NetworkInterface) -> Bool {
        lhs.id == rhs.id
    }
}

// Helper functions outside the view for concurrency safety
private func loadAllInterfaces() -> [NetworkInterface] {
    var ifaddrs: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddrs) == 0, let firstAddr = ifaddrs else { return [] }
    defer { freeifaddrs(ifaddrs) }
    
    var interfaceData: [String: (ipv4: String, ipv6: String, mac: String)] = [:]
    var interfaceNames: Set<String> = []
    
    // First pass: collect all interface names and addresses
    for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
        let name = String(cString: ptr.pointee.ifa_name)
        let family = ptr.pointee.ifa_addr.pointee.sa_family
        
        interfaceNames.insert(name)
        
        if interfaceData[name] == nil {
            interfaceData[name] = ("", "", "")
        }
        
        if family == UInt8(AF_INET) {
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(ptr.pointee.ifa_addr, socklen_t(ptr.pointee.ifa_addr.pointee.sa_len),
                       &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
            interfaceData[name]?.ipv4 = String(cString: hostname)
        } else if family == UInt8(AF_INET6) {
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(ptr.pointee.ifa_addr, socklen_t(ptr.pointee.ifa_addr.pointee.sa_len),
                       &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
            let ipv6 = String(cString: hostname)
            if interfaceData[name]?.ipv6.isEmpty == true {
                interfaceData[name]?.ipv6 = ipv6
            }
        } else if family == UInt8(AF_LINK) {
            let sdl = ptr.pointee.ifa_addr.withMemoryRebound(to: sockaddr_dl.self, capacity: 1) { $0.pointee }
            if sdl.sdl_alen == 6 {
                // Get MAC address bytes using pointer arithmetic
                let macData = ptr.pointee.ifa_addr.withMemoryRebound(to: sockaddr_dl.self, capacity: 1) { sdlPtr -> [UInt8] in
                    var bytes: [UInt8] = []
                    let sdlDataStart = UnsafeRawPointer(sdlPtr).advanced(by: 8 + Int(sdlPtr.pointee.sdl_nlen))
                    for i in 0..<6 {
                        bytes.append(sdlDataStart.load(fromByteOffset: i, as: UInt8.self))
                    }
                    return bytes
                }
                let mac = macData.map { String(format: "%02x", $0) }.joined(separator: ":")
                if mac != "00:00:00:00:00:00" {
                    interfaceData[name]?.mac = mac
                }
            }
        }
    }
    
    // Build interface objects
    var interfaces: [NetworkInterface] = []
    
    for name in interfaceNames {
        let data = interfaceData[name] ?? ("", "", "")
        let ifconfigOutput = runCommand("/sbin/ifconfig", arguments: [name])
        
        var mac = data.mac
        if mac.isEmpty {
            // Try to get MAC from ifconfig output
            for line in ifconfigOutput.components(separatedBy: "\n") {
                if line.contains("ether ") {
                    let parts = line.trimmingCharacters(in: .whitespaces).components(separatedBy: " ")
                    if let index = parts.firstIndex(of: "ether"), index + 1 < parts.count {
                        mac = parts[index + 1]
                        break
                    }
                }
            }
        }
        
        let linkStatus: String
        if ifconfigOutput.contains("status: active") {
            linkStatus = "Active"
        } else if ifconfigOutput.contains("status: inactive") {
            linkStatus = "Inactive"
        } else {
            linkStatus = "Unknown"
        }
        
        var linkSpeed = "N/A"
        if ifconfigOutput.contains("status: active") {
            for line in ifconfigOutput.components(separatedBy: "\n") {
                if line.contains("media:") {
                    if line.contains("1000baseT") { linkSpeed = "1 Gbps" }
                    else if line.contains("100baseT") { linkSpeed = "100 Mbps" }
                    else if line.contains("10baseT") { linkSpeed = "10 Mbps" }
                    else if line.contains("autoselect") { linkSpeed = "Auto" }
                    else { linkSpeed = "Active" }
                    break
                }
            }
        }
        
        let iface = NetworkInterface(
            id: name,
            name: name,
            displayName: getDisplayName(for: name),
            hardwareAddress: mac.isEmpty ? "N/A" : mac,
            ipAddress: data.ipv4,
            ipv6Address: data.ipv6,
            linkSpeed: linkSpeed,
            linkStatus: linkStatus,
            vendor: getVendor(for: name),
            model: getModel(for: name)
        )
        interfaces.append(iface)
    }
    
    return interfaces
        .filter { !$0.name.hasPrefix("utun") || !$0.ipAddress.isEmpty }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
}

private func getDisplayName(for name: String) -> String {
    switch name {
    case "en0": return "en0 (Wi-Fi)"
    case "en1": return "en1 (Ethernet)"
    case "en2": return "en2 (Ethernet 2)"
    case "en3": return "en3 (Ethernet 3)"
    case "lo0": return "lo0 (Loopback)"
    case "awdl0": return "awdl0 (AWDL)"
    case "bridge0": return "bridge0 (Thunderbolt Bridge)"
    case "llw0": return "llw0 (Low Latency WLAN)"
    default:
        if name.hasPrefix("utun") { return "\(name) (Tunnel)" }
        if name.hasPrefix("en") { return "\(name) (Ethernet)" }
        return name
    }
}

private func getVendor(for interface: String) -> String {
    if interface.hasPrefix("en") || interface == "awdl0" || interface == "llw0" {
        return "Apple"
    }
    return "N/A"
}

private func getModel(for interface: String) -> String {
    switch interface {
    case "en0": return "Wi-Fi Adapter"
    case "en1", "en2", "en3": return "Ethernet Adapter"
    case "lo0": return "Loopback"
    case "awdl0": return "Apple Wireless Direct Link"
    case "llw0": return "Low Latency WLAN"
    case "bridge0": return "Thunderbolt Bridge"
    default:
        if interface.hasPrefix("utun") { return "Virtual Tunnel" }
        return "N/A"
    }
}

private func fetchPacketStats(for interface: String) -> (sent: String, received: String, sendErrors: String, recvErrors: String, collisions: String) {
    let output = runCommand("/usr/sbin/netstat", arguments: ["-I", interface, "-b"])
    let lines = output.components(separatedBy: "\n")
    
    if lines.count >= 2 {
        let dataLine = lines[1]
        let parts = dataLine.split(separator: " ").map(String.init)
        
        if parts.count >= 11 {
            return (
                sent: parts[7],
                received: parts[4],
                sendErrors: parts[8],
                recvErrors: parts[5],
                collisions: parts[10]
            )
        }
    }
    
    return ("0", "0", "0", "0", "0")
}

struct InfoView: View {
    @State private var interfaces: [NetworkInterface] = []
    @State private var selectedInterfaceName: String = "en0"
    @State private var isLoading = true
    
    private var selectedInterface: NetworkInterface? {
        interfaces.first { $0.name == selectedInterfaceName }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select a network interface for information.")
                .font(.system(size: 12))
                .padding(.top, 16)
                .padding(.horizontal, 20)
            
            HStack(alignment: .top, spacing: 20) {
                Picker("", selection: $selectedInterfaceName) {
                    ForEach(interfaces) { iface in
                        Text(iface.displayName).tag(iface.name)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 200)
                .padding(.leading, 20)
                .disabled(isLoading)
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
                
                Spacer()
            }
            
            if let iface = selectedInterface {
                VStack(alignment: .leading, spacing: 6) {
                    InfoRow(label: "Interface:", value: iface.name)
                    Divider()
                    InfoRow(label: "Hardware Address:", value: iface.hardwareAddress)
                    Divider()
                    InfoRow(label: "IP Address:", value: iface.ipAddress)
                    Divider()
                    InfoRow(label: "IPv6 Address:", value: iface.ipv6Address)
                    Divider()
                    InfoRow(label: "Link Speed:", value: iface.linkSpeed)
                    Divider()
                    InfoRow(label: "Link Status:", value: iface.linkStatus)
                    Divider()
                    InfoRow(label: "Vendor:", value: iface.vendor)
                    Divider()
                    InfoRow(label: "Model:", value: iface.model)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )
                .padding(.horizontal, 20)
            } else if !isLoading {
                Text("No interface selected")
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
            }
            
            Spacer()
            
            if let iface = selectedInterface {
                TransferStatsView(interfaceName: iface.name)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }
        }
        .onAppear {
            loadInterfaces()
        }
    }
    
    private func loadInterfaces() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let loaded = loadAllInterfaces()
            DispatchQueue.main.async {
                interfaces = loaded
                if interfaces.contains(where: { $0.name == "en0" }) {
                    selectedInterfaceName = "en0"
                } else if let first = interfaces.first {
                    selectedInterfaceName = first.name
                }
                isLoading = false
            }
        }
    }
}

struct TransferStatsView: View {
    let interfaceName: String
    @State private var stats: (sent: String, received: String, sendErrors: String, recvErrors: String, collisions: String) = ("0", "0", "0", "0", "0")
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transfer Statistics")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            
            HStack(spacing: 32) {
                VStack(alignment: .leading, spacing: 4) {
                    StatRow(label: "Sent Packets:", value: stats.sent)
                    StatRow(label: "Send Errors:", value: stats.sendErrors)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    StatRow(label: "Recv Packets:", value: stats.received)
                    StatRow(label: "Recv Errors:", value: stats.recvErrors)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    StatRow(label: "Collisions:", value: stats.collisions)
                }
                
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
            )
        }
        .onChange(of: interfaceName) { newName in
            loadStats(for: newName)
        }
        .onAppear {
            loadStats(for: interfaceName)
        }
    }
    
    private func loadStats(for interface: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let newStats = fetchPacketStats(for: interface)
            DispatchQueue.main.async {
                stats = newStats
            }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 140, alignment: .trailing)
            Text(value.isEmpty ? "N/A" : value)
                .font(.system(size: 11, design: .monospaced))
                .textSelection(.enabled)
            Spacer()
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 11, design: .monospaced))
        }
    }
}

#Preview {
    InfoView()
}
