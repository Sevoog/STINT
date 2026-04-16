import SwiftUI

struct LookupView: View {
    @StateObject private var runner = CommandRunner()
    @State private var address: String = ""
    @State private var lookupType = 0
    
    let lookupTypes = [
        ("Default information", []),
        ("A (Address) records", ["A"]),
        ("AAAA (IPv6 Address) records", ["AAAA"]),
        ("Any (All) records", ["ANY"]),
        ("CNAME (Canonical Name) records", ["CNAME"]),
        ("MX (Mail Exchange) records", ["MX"]),
        ("NS (Name Server) records", ["NS"]),
        ("PTR (Pointer) records", ["PTR"]),
        ("SOA (Start of Authority) records", ["SOA"]),
        ("TXT (Text) records", ["TXT"])
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Enter the internet address to lookup.")
                .font(.system(size: 12))
                .padding(.top, 16)
                .padding(.horizontal, 20)
            
            HStack {
                TextField("", text: $address)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 250)
                
                Text("(ex. 17.254.0.91 or www.example.com)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            HStack {
                Text("Select the information to lookup:")
                    .font(.system(size: 12))
                
                Picker("", selection: $lookupType) {
                    ForEach(0..<lookupTypes.count, id: \.self) { index in
                        Text(lookupTypes[index].0).tag(index)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 250)
                
                Spacer()
                
                Button(action: runLookup) {
                    Text("Lookup")
                        .frame(width: 60)
                }
                .disabled(address.isEmpty || runner.isRunning)
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding(.horizontal, 20)
            
            // Output area
            OutputArea(text: runner.output, placeholder: "Enter an address and click Lookup.")
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
    
    private func runLookup() {
        var args: [String] = []
        
        let typeArgs = lookupTypes[lookupType].1
        if !typeArgs.isEmpty {
            args.append("-type=\(typeArgs[0])")
        }
        
        args.append(address)
        
        runner.run(command: "/usr/bin/nslookup", arguments: args)
    }
}

#Preview {
    LookupView()
}
