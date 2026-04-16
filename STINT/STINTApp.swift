import SwiftUI

@main
struct STINTApp: App {
    @State private var showMenuBarExtra = true
    
    var body: some Scene {
        // Main window
        WindowGroup {
            ContentView()
        }
        .windowStyle(.automatic)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            
            // Add View menu items
            CommandGroup(after: .windowArrangement) {
                Toggle("Show Menu Bar Icon", isOn: $showMenuBarExtra)
                    .keyboardShortcut("M", modifiers: [.command, .shift])
            }
        }
        
        // Menu bar extra (widget)
        MenuBarExtra("STINT", systemImage: "globe.americas.fill", isInserted: $showMenuBarExtra) {
            MenuBarWidget()
        }
        .menuBarExtraStyle(.window)
        
        // Settings window
        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}

// Settings view for preferences
struct SettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true
    @AppStorage("defaultPingHost") private var defaultPingHost = "8.8.8.8"
    @AppStorage("defaultPingCount") private var defaultPingCount = 10
    
    var body: some View {
        TabView {
            // General settings
            Form {
                Section {
                    Toggle("Launch at Login", isOn: $launchAtLogin)
                    Toggle("Show Menu Bar Icon", isOn: $showMenuBarIcon)
                }
                
                Section("Default Values") {
                    TextField("Default Ping Host:", text: $defaultPingHost)
                        .textFieldStyle(.roundedBorder)
                    
                    Stepper("Default Ping Count: \(defaultPingCount)", value: $defaultPingCount, in: 1...100)
                }
            }
            .padding(20)
            .frame(width: 400, height: 200)
            .tabItem {
                Label("General", systemImage: "gear")
            }
            
            // About
            VStack(spacing: 16) {
                // Use the app icon from the bundle
                if let appIcon = NSApplication.shared.applicationIconImage {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 100, maxHeight: 100)
                } else {
                    // Fallback to recreating the icon look
                    Image(systemName: "globe.americas.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.accentColor)
                }
                
                Text("STINT")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Sev's Tiny Internet Network Tool")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Version 1.0")
                    .foregroundColor(.secondary)
                
                Text("A modern network utility for macOS")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Spacer()
            }
            .padding(20)
            .frame(width: 400, height: 220)
            .tabItem {
                Label("About", systemImage: "info.circle")
            }
        }
    }
}

#Preview {
    SettingsView()
}
