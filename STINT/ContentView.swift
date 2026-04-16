import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                TabButton(title: "Info", index: 0, selectedTab: $selectedTab)
                TabButton(title: "Netstat", index: 1, selectedTab: $selectedTab)
                TabButton(title: "Ping", index: 2, selectedTab: $selectedTab)
                TabButton(title: "Lookup", index: 3, selectedTab: $selectedTab)
                TabButton(title: "Traceroute", index: 4, selectedTab: $selectedTab)
                TabButton(title: "Whois", index: 5, selectedTab: $selectedTab)
                TabButton(title: "Finger", index: 6, selectedTab: $selectedTab)
                TabButton(title: "Port Scan", index: 7, selectedTab: $selectedTab)
                TabButton(title: "Bonjour", index: 8, selectedTab: $selectedTab)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            
            Divider()
                .padding(.top, 8)
            
            // Content area with fixed frame to prevent layout shifts
            ZStack {
                switch selectedTab {
                case 0:
                    InfoView()
                case 1:
                    NetstatView()
                case 2:
                    PingView()
                case 3:
                    LookupView()
                case 4:
                    TracerouteView()
                case 5:
                    WhoisView()
                case 6:
                    FingerView()
                case 7:
                    PortScanView()
                case 8:
                    BonjourView()
                default:
                    InfoView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 750, height: 520)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct TabButton: View {
    let title: String
    let index: Int
    @Binding var selectedTab: Int
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedTab = index
            }
        }) {
            Text(title)
                .font(.system(size: 11))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(selectedTab == index ? Color.accentColor : Color.clear)
                )
                .foregroundColor(selectedTab == index ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
}
