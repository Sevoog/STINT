import SwiftUI

struct PingView: View {
    @StateObject private var runner = CommandRunner()
    @State private var address: String = ""
    @State private var pingCount: String = "10"
    @State private var unlimitedPings: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Enter the network address to ping.")
                .font(.system(size: 12))
                .padding(.top, 16)
                .padding(.horizontal, 20)
            
            HStack {
                TextField("", text: $address)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                
                Text("(ex. 10.0.2.1 or www.example.com)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            RadioButton(title: "Send an unlimited number of pings", isSelected: unlimitedPings) {
                unlimitedPings = true
            }
            .padding(.horizontal, 20)
            
            HStack(spacing: 8) {
                RadioButton(title: "Send only", isSelected: !unlimitedPings) {
                    unlimitedPings = false
                }
                
                TextField("", text: $pingCount)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 50)
                    .disabled(unlimitedPings)
                
                Text("pings")
                    .font(.system(size: 12))
                
                Spacer()
                
                // Export button
                ExportButton(
                    title: "Ping_\(address.isEmpty ? "results" : address)",
                    output: runner.output,
                    command: "ping \(unlimitedPings ? "" : "-c \(pingCount) ")\(address)"
                )
                
                Button(action: runPing) {
                    Text("Ping")
                        .frame(width: 50)
                }
                .disabled(address.isEmpty || runner.isRunning)
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding(.horizontal, 20)
            
            // Output area with better contrast
            ScrollingOutputArea(text: runner.output, placeholder: "")
                .padding(.horizontal, 20)
            
            if runner.isRunning {
                StatusRow(isRunning: true, message: "Ping has started...") {
                    runner.stop()
                }
            } else {
                Spacer().frame(height: 32)
            }
        }
        .padding(.bottom, 12)
    }
    
    private func runPing() {
        var args: [String] = []
        
        if !unlimitedPings, let count = Int(pingCount), count > 0 {
            args.append("-c")
            args.append(String(count))
        }
        
        args.append(address)
        
        runner.output = "Ping has started...\n\n"
        runner.run(command: "/sbin/ping", arguments: args)
    }
}

#Preview {
    PingView()
}
