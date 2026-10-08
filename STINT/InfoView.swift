// InfoView.swift
// STINT — Sev's Tiny Internet Network Tool
// Created by Sevag Bardakjian
// Copyright © 2026 Sevag Bardakjian
// SPDX-License-Identifier: GPL-3.0-only

import SwiftUI
import Network
import SystemConfiguration
import IOKit

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
        // Some interfaces have no address at all; dereferencing it would crash.
        guard let addr = ptr.pointee.ifa_addr else { continue }
        let name = String(cString: ptr.pointee.ifa_name)
        let family = addr.pointee.sa_family
        
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
    let systemInterfaces = loadSystemInterfaces()

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
                    if let speed = parseLinkSpeed(fromMediaLine: line) { linkSpeed = speed }
                    else if line.contains("autoselect") { linkSpeed = "Auto" }
                    else { linkSpeed = "Active" }
                    break
                }
            }
        }
        
        let system = systemInterfaces[name]
        let hardware = hardwareVendorModel(for: name)
        let iface = NetworkInterface(
            id: name,
            name: name,
            displayName: system.map { "\(name) (\($0.displayName))" } ?? getDisplayName(for: name),
            hardwareAddress: mac.isEmpty ? "N/A" : mac,
            ipAddress: data.ipv4,
            ipv6Address: data.ipv6,
            linkSpeed: linkSpeed,
            linkStatus: linkStatus,
            vendor: hardware.vendor ?? getVendor(for: name, type: system?.type),
            model: hardware.model ?? getModel(for: name, type: system?.type)
        )
        interfaces.append(iface)
    }
    
    return interfaces
        .filter { !$0.name.hasPrefix("utun") || !$0.ipAddress.isEmpty }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
}

// The names macOS itself shows in System Settings ("Wi-Fi", "Thunderbolt Ethernet Slot 0",
// "Thunderbolt Bridge"), keyed by BSD name. en0/en1 mean different hardware on different
// Macs, so these can't be hard-coded.
private func loadSystemInterfaces() -> [String: (displayName: String, type: String?)] {
    var result: [String: (displayName: String, type: String?)] = [:]
    for iface in SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] ?? [] {
        guard let bsdName = SCNetworkInterfaceGetBSDName(iface) as String?,
              let displayName = SCNetworkInterfaceGetLocalizedDisplayName(iface) as String? else { continue }
        result[bsdName] = (displayName, SCNetworkInterfaceGetInterfaceType(iface) as String?)
    }
    return result
}

// Vendor and model as reported by the network controller's driver (e.g. "Aquantia" / "AQC113"),
// the same place the classic Network Utility read them from. Many interfaces don't report them.
private func hardwareVendorModel(for bsdName: String) -> (vendor: String?, model: String?) {
    let service = IOServiceGetMatchingService(kIOMainPortDefault, IOBSDNameMatching(kIOMainPortDefault, 0, bsdName))
    guard service != 0 else { return (nil, nil) }
    defer { IOObjectRelease(service) }

    var controller: io_registry_entry_t = 0
    guard IORegistryEntryGetParentEntry(service, kIOServicePlane, &controller) == KERN_SUCCESS else { return (nil, nil) }
    defer { IOObjectRelease(controller) }

    func property(_ key: String) -> String? {
        let value = IORegistryEntryCreateCFProperty(controller, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String
        return value?.isEmpty == false ? value : nil
    }
    return (property("IOVendor"), property("IOModel"))
}

// Turns an ifconfig media line such as "media: autoselect (2500Base-T <full-duplex>)" into
// "2.5 Gbps". Returns nil when the line names no speed (Wi-Fi, Thunderbolt, inactive).
private func parseLinkSpeed(fromMediaLine line: String) -> String? {
    guard let match = line.range(of: #"\d+(\.\d+)?\s*G?base"#, options: [.regularExpression, .caseInsensitive]) else { return nil }
    let token = line[match].lowercased()
    let isGigabit = token.contains("g")
    guard let value = Double(token.prefix { $0.isNumber || $0 == "." }) else { return nil }

    let mbps = isGigabit ? value * 1000 : value
    if mbps >= 1000 {
        let gbps = mbps / 1000
        return gbps == gbps.rounded() ? "\(Int(gbps)) Gbps" : "\(gbps) Gbps"
    }
    return "\(Int(mbps)) Mbps"
}

// Fallback names for interfaces System Settings doesn't list (loopback, AWDL, tunnels).
private func getDisplayName(for name: String) -> String {
    switch name {
    case "lo0": return "lo0 (Loopback)"
    case "awdl0": return "awdl0 (AWDL)"
    case "llw0": return "llw0 (Low Latency WLAN)"
    default:
        if name.hasPrefix("utun") { return "\(name) (Tunnel)" }
        if name.hasPrefix("bridge") { return "\(name) (Bridge)" }
        return name
    }
}

private func getVendor(for interface: String, type: String?) -> String {
    // Built-in Wi-Fi and its peer-to-peer companions don't report a vendor to IOKit.
    if type == (kSCNetworkInterfaceTypeIEEE80211 as String) || interface == "awdl0" || interface == "llw0" {
        return "Apple"
    }
    return "N/A"
}

private func getModel(for interface: String, type: String?) -> String {
    if type == (kSCNetworkInterfaceTypeIEEE80211 as String) { return "Wi-Fi Adapter" }
    if type == (kSCNetworkInterfaceTypeEthernet as String) { return "Ethernet Adapter" }
    if type == "Bridge" { return "Network Bridge" }  // the SDK has no constant for this type
    switch interface {
    case "lo0": return "Loopback"
    case "awdl0": return "Apple Wireless Direct Link"
    case "llw0": return "Low Latency WLAN"
    default:
        if interface.hasPrefix("utun") { return "Virtual Tunnel" }
        return "N/A"
    }
}

private func fetchPacketStats(for interface: String) -> (sent: String, received: String, sendErrors: String, recvErrors: String, collisions: String) {
    let output = runCommand("/usr/sbin/netstat", arguments: ["-I", interface, "-b"])
    return parsePacketStats(netstatOutput: output)
}

// Parses `netstat -I <iface> -b`. The Address column is blank for interfaces without a MAC
// (lo0, utun), which shifts every column after it, so read the seven counters from the right:
// Ipkts Ierrs Ibytes Opkts Oerrs Obytes Coll.
private func parsePacketStats(netstatOutput output: String) -> (sent: String, received: String, sendErrors: String, recvErrors: String, collisions: String) {
    let lines = output.components(separatedBy: "\n")
    
    if lines.count >= 2 {
        let parts = lines[1].split(separator: " ").map(String.init)

        if parts.count >= 8 {
            let counters = Array(parts.suffix(7))
            return (
                sent: counters[3],
                received: counters[0],
                sendErrors: counters[4],
                recvErrors: counters[1],
                collisions: counters[6]
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
