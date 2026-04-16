import SwiftUI

struct FingerView: View {
    @StateObject private var runner = CommandRunner()
    @State private var address: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Enter the user name and address to finger.")
                .font(.system(size: 12))
                .padding(.top, 16)
                .padding(.horizontal, 20)
            
            HStack {
                TextField("", text: $address)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 250)
                
                Text("(ex. user@example.com)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: runFinger) {
                    Text("Finger")
                        .frame(width: 60)
                }
                .disabled(address.isEmpty || runner.isRunning)
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding(.horizontal, 20)
            
            // Output area
            OutputArea(
                text: runner.output,
                placeholder: "Enter a user address and click Finger.\n\nNote: The Finger protocol (RFC 1288) is largely deprecated and most servers no longer support it."
            )
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
    
    private func runFinger() {
        runner.run(command: "/usr/bin/finger", arguments: [address])
    }
}

#Preview {
    FingerView()
}
