import SwiftUI
import Network

// Model for discovered Bonjour services
struct BonjourService: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let type: String
    let domain: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: BonjourService, rhs: BonjourService) -> Bool {
        lhs.id == rhs.id
    }
}

// Common Bonjour service types
struct ServiceType: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let type: String
    
    static let commonTypes: [ServiceType] = [
        ServiceType(name: "Web Servers (HTTP)", type: "_http._tcp"),
        ServiceType(name: "Secure Web (HTTPS)", type: "_https._tcp"),
        ServiceType(name: "SSH", type: "_ssh._tcp"),
        ServiceType(name: "SFTP", type: "_sftp-ssh._tcp"),
        ServiceType(name: "AFP (Apple Filing)", type: "_afpovertcp._tcp"),
        ServiceType(name: "SMB (Windows Sharing)", type: "_smb._tcp"),
        ServiceType(name: "FTP", type: "_ftp._tcp"),
        ServiceType(name: "Printers", type: "_printer._tcp"),
        ServiceType(name: "IPP Printers", type: "_ipp._tcp"),
        ServiceType(name: "AirPlay", type: "_airplay._tcp"),
        ServiceType(name: "AirPlay Audio (RAOP)", type: "_raop._tcp"),
        ServiceType(name: "Spotify Connect", type: "_spotify-connect._tcp"),
        ServiceType(name: "Google Cast", type: "_googlecast._tcp"),
        ServiceType(name: "HomeKit", type: "_hap._tcp"),
        ServiceType(name: "Apple Remote Desktop", type: "_eppc._tcp"),
        ServiceType(name: "VNC (Screen Sharing)", type: "_rfb._tcp"),
        ServiceType(name: "iTunes/Music Sharing", type: "_daap._tcp"),
        ServiceType(name: "Time Machine", type: "_adisk._tcp"),
        ServiceType(name: "Apple TV", type: "_appletv-v2._tcp"),
        ServiceType(name: "AirPort Base Station", type: "_airport._tcp"),
    ]
}

// Bonjour browser using NWBrowser
class BonjourBrowser: ObservableObject {
    @Published var services: [BonjourService] = []
    @Published var isSearching = false
    @Published var statusMessage = ""
    
    private var browsers: [NWBrowser] = []
    
    // Browse for a single service type
    func browse(serviceType: String) {
        stop()
        services = []
        isSearching = true
        statusMessage = "Searching for \(serviceType) services..."
        
        startBrowser(for: serviceType)
    }
    
    // Browse for all common service types simultaneously
    func browseAll() {
        stop()
        services = []
        isSearching = true
        statusMessage = "Searching for all common services..."
        
        for serviceType in ServiceType.commonTypes {
            startBrowser(for: serviceType.type)
        }
    }
    
    private func startBrowser(for serviceType: String) {
        // Use .bonjour instead of .bonjourWithTXTRecord to avoid issues
        let descriptor = NWBrowser.Descriptor.bonjour(type: serviceType, domain: "local.")
        
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        
        let newBrowser = NWBrowser(for: descriptor, using: parameters)
        
        newBrowser.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    if self?.browsers.count == 1 {
                        self?.statusMessage = "Browsing for services..."
                    }
                case .failed(let error):
                    // Only show error if it's the only browser or a significant error
                    if self?.browsers.count == 1 {
                        self?.statusMessage = "Error: \(error.localizedDescription)"
                        self?.isSearching = false
                    }
                case .cancelled:
                    break
                default:
                    break
                }
            }
        }
        
        newBrowser.browseResultsChangedHandler = { [weak self] results, _ in
            DispatchQueue.main.async {
                self?.processResults(results)
            }
        }
        
        browsers.append(newBrowser)
        newBrowser.start(queue: .main)
    }
    
    private func processResults(_ results: Set<NWBrowser.Result>) {
        for result in results {
            switch result.endpoint {
            case .service(let name, let type, let domain, _):
                // Check if we already have this service (by name and type)
                let exists = services.contains { $0.name == name && $0.type == type }
                if !exists {
                    let service = BonjourService(
                        name: name,
                        type: type,
                        domain: domain
                    )
                    services.append(service)
                }
            default:
                break
            }
        }
        
        services.sort { $0.name.lowercased() < $1.name.lowercased() }
        statusMessage = "Found \(services.count) service\(services.count == 1 ? "" : "s")"
    }
    
    func stop() {
        for browser in browsers {
            browser.cancel()
        }
        browsers = []
        isSearching = false
    }
}

struct BonjourView: View {
    @StateObject private var browser = BonjourBrowser()
    @State private var selectedServiceType: ServiceType = ServiceType.commonTypes[0]
    @State private var customServiceType = ""
    @State private var useCustomType = false
    @State private var browseAllTypes = false
    @State private var selectedService: BonjourService?

    private var resultsText: String {
        guard !browser.services.isEmpty else { return "" }
        var text = "Name\tType\tDomain\n"
        for service in browser.services {
            text += "\(service.name)\t\(service.type)\t\(service.domain)\n"
        }
        return text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Service type selection
            HStack(spacing: 12) {
                Text("Service Type:")
                    .font(.system(size: 12))
                
                if browseAllTypes {
                    Text("All Common Types")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .frame(width: 200, alignment: .leading)
                } else if useCustomType {
                    TextField("e.g., _http._tcp", text: $customServiceType)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                        .font(.system(size: 12))
                } else {
                    Picker("", selection: $selectedServiceType) {
                        ForEach(ServiceType.commonTypes) { serviceType in
                            Text(serviceType.name).tag(serviceType)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 200)
                }
                
                Toggle("Custom", isOn: $useCustomType)
                    .font(.system(size: 12))
                    .disabled(browseAllTypes)
                    .onChange(of: useCustomType) { _ in
                        if useCustomType { browseAllTypes = false }
                    }
                
                Toggle("All", isOn: $browseAllTypes)
                    .font(.system(size: 12))
                    .onChange(of: browseAllTypes) { _ in
                        if browseAllTypes { useCustomType = false }
                    }
                
                Spacer()

                ExportButton(
                    title: "Bonjour_services",
                    output: resultsText,
                    command: browseAllTypes ? "browse all common services" : "browse \(useCustomType ? customServiceType : selectedServiceType.type)"
                )

                Button(browser.isSearching ? "Stop" : "Browse") {
                    if browser.isSearching {
                        browser.stop()
                    } else {
                        if browseAllTypes {
                            browser.browseAll()
                        } else {
                            let type = useCustomType ? customServiceType : selectedServiceType.type
                            if !type.isEmpty {
                                browser.browse(serviceType: type)
                            }
                        }
                    }
                }
                .disabled(!browser.isSearching && useCustomType && customServiceType.isEmpty)
                .glassActionButton()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            // Results list
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Text("Name")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 250, alignment: .leading)
                    Text("Type")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 180, alignment: .leading)
                    Text("Domain")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                // Service list
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if browser.services.isEmpty && !browser.isSearching {
                            Text("No services found. Click Browse to search.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .padding(12)
                        } else {
                            ForEach(browser.services) { service in
                                HStack {
                                    Text(service.name)
                                        .font(.system(size: 11, design: .monospaced))
                                        .frame(width: 250, alignment: .leading)
                                        .lineLimit(1)
                                    Text(service.type)
                                        .font(.system(size: 11, design: .monospaced))
                                        .frame(width: 180, alignment: .leading)
                                        .lineLimit(1)
                                        .foregroundColor(.secondary)
                                    Text(service.domain)
                                        .font(.system(size: 11, design: .monospaced))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .lineLimit(1)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(selectedService?.id == service.id ? Color.accentColor.opacity(0.2) : Color.clear)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedService = service
                                }
                            }
                        }
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            
            // Status bar
            HStack {
                if browser.isSearching {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                }
                Text(browser.statusMessage)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let service = selectedService {
                    Text("Selected: \(service.name)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
    }
}

#Preview {
    BonjourView()
        .frame(width: 750, height: 450)
}
