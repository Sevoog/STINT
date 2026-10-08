// MenuBarWidget.swift
// STINT — Sev's Tiny Internet Network Tool
// Created by Sevag Bardakjian
// Copyright © 2026 Sevag Bardakjian
// SPDX-License-Identifier: GPL-3.0-only

import SwiftUI
import Network

// Connection status and local IP for the menu bar. One monitor for the app's lifetime: the
// menu bar view appears every time the menu opens, and starting a monitor per appearance
// leaked one each time. The IP refreshes whenever the network changes.
final class NetworkStatusMonitor: ObservableObject {
    static let shared = NetworkStatusMonitor()

    @Published private(set) var connectionStatus = "Unknown"
    @Published private(set) var currentIP = "Checking..."

    private let monitor = NWPathMonitor()

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let ip = localIPv4Address(for: path) ?? "Not available"
            DispatchQueue.main.async {
                self?.connectionStatus = path.status == .satisfied ? "Connected" : "Disconnected"
                self?.currentIP = ip
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.sevag.stint.network-status"))
    }
}

// The address of the Wi-Fi or Ethernet interface carrying traffic. A VPN's tunnel interface
// can be listed first, but its address isn't the Mac's address on the local network.
private func localIPv4Address(for path: NWPath) -> String? {
    let addresses = ipv4AddressesByInterface()
    let physical = path.availableInterfaces.filter { $0.type == .wifi || $0.type == .wiredEthernet }
    for iface in physical {
        if let ip = addresses.first(where: { $0.name == iface.name })?.ip { return ip }
    }
    return addresses.first?.ip
}

// Non-loopback IPv4 addresses in interface order.
private func ipv4AddressesByInterface() -> [(name: String, ip: String)] {
    var result: [(name: String, ip: String)] = []
    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return result }
    defer { freeifaddrs(ifaddr) }

    for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
        // Some interfaces have no address at all; dereferencing it would crash.
        guard let addr = ptr.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) else { continue }
        let name = String(cString: ptr.pointee.ifa_name)
        guard name != "lo0" else { continue }

        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        getnameinfo(addr, socklen_t(addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
        let ip = String(cString: hostname)
        if !ip.isEmpty && !ip.hasPrefix("127.") {
            result.append((name, ip))
        }
    }
    return result
}

// Menu bar extra for quick network actions
struct MenuBarWidget: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject private var network = NetworkStatusMonitor.shared
    @State private var pingResult = ""
    @State private var isPinging = false

    private var connectionStatus: String { network.connectionStatus }
    private var currentIP: String { network.currentIP }

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
                        .foregroundColor(pingResult.isEmpty ? .secondary : pingResult.hasSuffix("ms") ? .green : .red)
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
            
            // Wait for exit via the termination handler rather than waitUntilExit(), which
            // would block one of Swift's shared concurrency threads for up to two seconds.
            process.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
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
                continuation.resume(returning: "error")
            }

            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                continuation.resume(returning: "error")
            }
        }
    }
    
    private func openMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        // Brings the main window forward, or reopens it if it was closed.
        openWindow(id: mainWindowID, value: mainWindowValue)
    }
    
    private func copyIPToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(currentIP, forType: .string)
    }
}

#Preview {
    MenuBarWidget()
}
