import SwiftUI

struct FingerView: View {
    var body: some View {
        AddressCommandTool(
            hint: "Enter the user name and address to finger.",
            example: "(ex. user@example.com)",
            buttonTitle: "Finger",
            placeholder: "Enter a user address and click Finger.\n\nNote: The Finger protocol (RFC 1288) is largely deprecated and most servers no longer support it.",
            runningMessage: "Looking up...",
            exportPrefix: "Finger",
            commandPath: "/usr/bin/finger",
            makeArguments: { [$0] },
            commandDescription: { "finger \($0)" }
        )
    }
}

#Preview {
    FingerView()
}
