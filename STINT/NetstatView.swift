import SwiftUI

struct NetstatView: View {
    @StateObject private var runner = CommandRunner()
    @State private var displayOption = 0
    @State private var protocolOption = 0
    
    let displayOptions = [
        ("Routing table information", ["-r"]),
        ("Comprehensive network statistics", ["-s"]),
        ("Multicast information", ["-g"]),
        ("State of network data structures", ["-a"])
    ]
    
    let protocolOptions = [
        ("All", []),
        ("TCP", ["-p", "tcp"]),
        ("UDP", ["-p", "udp"]),
        ("ICMP", ["-p", "icmp"])
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Display:")
                .font(.system(size: 12))
                .padding(.top, 16)
                .padding(.horizontal, 20)
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(0..<displayOptions.count, id: \.self) { index in
                    RadioButton(title: displayOptions[index].0, isSelected: displayOption == index) {
                        displayOption = index
                    }
                }
            }
            .padding(.horizontal, 20)
            
            HStack {
                Text("Protocol:")
                    .font(.system(size: 12))
                
                Picker("", selection: $protocolOption) {
                    ForEach(0..<protocolOptions.count, id: \.self) { index in
                        Text(protocolOptions[index].0).tag(index)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 100)
                
                Spacer()

                ExportButton(
                    title: "Netstat_\(displayOptions[displayOption].0)",
                    output: runner.output,
                    command: "netstat \((displayOptions[displayOption].1 + protocolOptions[protocolOption].1).joined(separator: " "))"
                )

                Button(action: runNetstat) {
                    Text("Netstat")
                        .frame(width: 70)
                }
                .disabled(runner.isRunning)
                .glassActionButton()
            }
            .padding(.horizontal, 20)
            
            // Output area
            OutputArea(text: runner.output, placeholder: "Click Netstat to display network statistics.")
                .padding(.horizontal, 20)
            
            if runner.isRunning {
                StatusRow(isRunning: true, message: "Running netstat...") {
                    runner.stop()
                }
            } else {
                Spacer().frame(height: 32)
            }
        }
        .padding(.bottom, 12)
    }
    
    private func runNetstat() {
        var args = displayOptions[displayOption].1
        args.append(contentsOf: protocolOptions[protocolOption].1)
        runner.run(command: "/usr/sbin/netstat", arguments: args)
    }
}

#Preview {
    NetstatView()
}
