import SwiftUI
import ServiceManagement

// STINT has one main window. Giving it a fixed value means openWindow(id:value:) brings the
// existing window forward, or recreates it if it was closed, instead of stacking duplicates.
let mainWindowID = "main"
let mainWindowValue = "main"

var appVersion: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
}

@main
struct STINTApp: App {
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true

    var body: some Scene {
        // Main window. A WindowGroup rather than a Window scene: closing a Window scene
        // quits the app, which would take the menu bar widget with it.
        WindowGroup(id: mainWindowID, for: String.self) { _ in
            ContentView()
        } defaultValue: {
            mainWindowValue
        }
        .windowStyle(.automatic)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            
            // Add View menu items
            CommandGroup(after: .windowArrangement) {
                Toggle("Show Menu Bar Icon", isOn: $showMenuBarIcon)
                    .keyboardShortcut("M", modifiers: [.command, .shift])
            }
        }
        
        // Menu bar extra (widget)
        MenuBarExtra("STINT", systemImage: "globe.americas.fill", isInserted: $showMenuBarIcon) {
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

    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            // System call failed — snap the toggle back to the real state
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
        }
    }

    var body: some View {
        TabView {
            // General settings
            Form {
                Section {
                    Toggle("Launch at Login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { enabled in
                            updateLaunchAtLogin(enabled)
                        }
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
            .onAppear {
                launchAtLogin = (SMAppService.mainApp.status == .enabled)
            }
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
                
                Text("Version \(appVersion)")
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
