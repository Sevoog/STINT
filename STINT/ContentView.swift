import SwiftUI

// The set of tools shown in the tab bar. Adding or reordering a tool is a single
// change here — the tab bar and content area are both derived from this enum.
enum Tool: String, CaseIterable, Identifiable {
    case info = "Info"
    case netstat = "Netstat"
    case ping = "Ping"
    case lookup = "Lookup"
    case traceroute = "Traceroute"
    case whois = "Whois"
    case finger = "Finger"
    case portScan = "Port Scan"
    case bonjour = "Bonjour"

    var id: String { rawValue }
    var title: String { rawValue }

    @ViewBuilder
    var view: some View {
        switch self {
        case .info: InfoView()
        case .netstat: NetstatView()
        case .ping: PingView()
        case .lookup: LookupView()
        case .traceroute: TracerouteView()
        case .whois: WhoisView()
        case .finger: FingerView()
        case .portScan: PortScanView()
        case .bonjour: BonjourView()
        }
    }
}

struct ContentView: View {
    @State private var selectedTool: Tool = .info

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                ForEach(Tool.allCases) { tool in
                    TabButton(tool: tool, selectedTool: $selectedTool)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            Divider()
                .padding(.top, 8)

            // Content area with fixed frame to prevent layout shifts
            ZStack {
                selectedTool.view
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 750, height: 520)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct TabButton: View {
    let tool: Tool
    @Binding var selectedTool: Tool

    private var isSelected: Bool { selectedTool == tool }

    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedTool = tool
            }
        }) {
            Text(tool.title)
                .font(.system(size: 11))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color.clear)
                )
                .foregroundColor(isSelected ? .white : .secondary)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
}
