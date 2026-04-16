import SwiftUI

struct TracerouteView: View {
    @StateObject private var runner = CommandRunner()
    @State private var address: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Enter the address to trace a route to.")
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
                
                ExportButton(
                    title: "Traceroute_\(address.isEmpty ? "results" : address)",
                    output: runner.output,
                    command: "traceroute \(address)"
                )
                
                Button(action: runTraceroute) {
                    Text("Trace")
                        .frame(width: 50)
                }
                .disabled(address.isEmpty || runner.isRunning)
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding(.horizontal, 20)
            
            // Output area
            ScrollingOutputArea(text: runner.output, placeholder: "Enter an address and click Trace.")
                .padding(.horizontal, 20)
            
            if runner.isRunning {
                StatusRow(isRunning: true, message: "Traceroute has started...") {
                    runner.stop()
                }
            } else {
                Spacer().frame(height: 32)
            }
        }
        .padding(.bottom, 12)
    }
    
    private func runTraceroute() {
        runner.output = "Traceroute has started...\n\n"
        runner.run(command: "/usr/sbin/traceroute", arguments: [address])
    }
}

#Preview {
    TracerouteView()
}
