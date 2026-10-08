import SwiftUI

struct TracerouteView: View {
    var body: some View {
        AddressCommandTool(
            hint: "Enter the address to trace a route to.",
            example: "(ex. 10.0.2.1 or www.example.com)",
            buttonTitle: "Trace",
            placeholder: "Enter an address and click Trace.",
            runningMessage: "Traceroute has started...",
            exportPrefix: "Traceroute",
            commandPath: "/usr/sbin/traceroute",
            makeArguments: { [$0] },
            commandDescription: { "traceroute \($0)" },
            scrolling: true,
            runningPreamble: "Traceroute has started...\n\n",
            buttonWidth: 50
        )
    }
}

#Preview {
    TracerouteView()
}
