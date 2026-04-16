import SwiftUI

struct WhoisView: View {
    @StateObject private var runner = CommandRunner()
    @State private var address: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Enter a domain name or IP address to look up.")
                .font(.system(size: 12))
                .padding(.top, 16)
                .padding(.horizontal, 20)
            
            HStack {
                TextField("", text: $address)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 250)
                
                Text("(ex. example.com or 10.0.2.1)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: runWhois) {
                    Text("Whois")
                        .frame(width: 60)
                }
                .disabled(address.isEmpty || runner.isRunning)
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding(.horizontal, 20)
            
            // Output area
            OutputArea(text: runner.output, placeholder: "Enter a domain and click Whois.")
                .padding(.horizontal, 20)
            
            if runner.isRunning {
                StatusRow(isRunning: true, message: "Looking up...") {
                    runner.stop()
                }
            } else {
                Spacer().frame(height: 32)
            }
        }
        .padding(.bottom, 12)
    }
    
    private func runWhois() {
        runner.run(command: "/usr/bin/whois", arguments: [address])
    }
}

#Preview {
    WhoisView()
}
