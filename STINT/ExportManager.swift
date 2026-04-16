import SwiftUI
import UniformTypeIdentifiers

// Export formats supported
enum ExportFormat: String, CaseIterable, Identifiable {
    case txt = "Plain Text (.txt)"
    case csv = "CSV (.csv)"
    case json = "JSON (.json)"
    
    var id: String { rawValue }
    
    var fileExtension: String {
        switch self {
        case .txt: return "txt"
        case .csv: return "csv"
        case .json: return "json"
        }
    }
    
    var utType: UTType {
        switch self {
        case .txt: return .plainText
        case .csv: return .commaSeparatedText
        case .json: return .json
        }
    }
}

// Export data container
struct ExportData {
    let title: String
    let timestamp: Date
    let command: String?
    let output: String
    let metadata: [String: String]?
    
    // Convert to different formats
    func toPlainText() -> String {
        var result = "=== \(title) ===\n"
        result += "Timestamp: \(formatDate(timestamp))\n"
        if let cmd = command {
            result += "Command: \(cmd)\n"
        }
        if let meta = metadata {
            result += "---\n"
            for (key, value) in meta.sorted(by: { $0.key < $1.key }) {
                result += "\(key): \(value)\n"
            }
        }
        result += "---\n\n"
        result += output
        return result
    }
    
    func toCSV() -> String {
        // For tabular data, try to parse the output
        let lines = output.components(separatedBy: "\n")
        
        // Simple CSV: each line becomes a row, fields separated by whitespace
        var csv = "timestamp,title,data\n"
        let ts = formatDate(timestamp)
        for line in lines where !line.isEmpty {
            let escaped = line.replacingOccurrences(of: "\"", with: "\"\"")
            csv += "\"\(ts)\",\"\(title)\",\"\(escaped)\"\n"
        }
        return csv
    }
    
    func toJSON() -> String {
        var dict: [String: Any] = [
            "title": title,
            "timestamp": formatDate(timestamp),
            "output": output
        ]
        if let cmd = command {
            dict["command"] = cmd
        }
        if let meta = metadata {
            dict["metadata"] = meta
        }
        
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        return "{}"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}

// Export manager handles file saving
class ExportManager {
    static let shared = ExportManager()
    
    private init() {}
    
    func export(data: ExportData, format: ExportFormat, completion: @escaping (Bool, String?) -> Void) {
        let content: String
        switch format {
        case .txt:
            content = data.toPlainText()
        case .csv:
            content = data.toCSV()
        case .json:
            content = data.toJSON()
        }
        
        // Create save panel
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format.utType]
        panel.nameFieldStringValue = "\(sanitizeFilename(data.title))_\(fileTimestamp()).\(format.fileExtension)"
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.title = "Export Results"
        panel.message = "Choose a location to save the export file"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try content.write(to: url, atomically: true, encoding: .utf8)
                    completion(true, url.path)
                } catch {
                    completion(false, error.localizedDescription)
                }
            } else {
                completion(false, nil) // User cancelled
            }
        }
    }
    
    // Quick export to Downloads folder
    func quickExport(data: ExportData, format: ExportFormat) -> (Bool, String) {
        let content: String
        switch format {
        case .txt:
            content = data.toPlainText()
        case .csv:
            content = data.toCSV()
        case .json:
            content = data.toJSON()
        }
        
        let filename = "\(sanitizeFilename(data.title))_\(fileTimestamp()).\(format.fileExtension)"
        
        if let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
            let fileURL = downloadsURL.appendingPathComponent(filename)
            do {
                try content.write(to: fileURL, atomically: true, encoding: .utf8)
                return (true, fileURL.path)
            } catch {
                return (false, error.localizedDescription)
            }
        }
        return (false, "Could not access Downloads folder")
    }
    
    private func sanitizeFilename(_ name: String) -> String {
        let invalidChars = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return name.components(separatedBy: invalidChars).joined(separator: "_")
    }
    
    private func fileTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }
}

// SwiftUI view for export button with menu
struct ExportButton: View {
    let title: String
    let output: String
    let command: String?
    let metadata: [String: String]?
    
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertSuccess = false
    
    init(title: String, output: String, command: String? = nil, metadata: [String: String]? = nil) {
        self.title = title
        self.output = output
        self.command = command
        self.metadata = metadata
    }
    
    var body: some View {
        Menu {
            Button("Export as Text (.txt)") {
                exportWith(format: .txt)
            }
            Button("Export as CSV (.csv)") {
                exportWith(format: .csv)
            }
            Button("Export as JSON (.json)") {
                exportWith(format: .json)
            }
            Divider()
            Menu("Quick Export to Downloads") {
                Button("As Text (.txt)") {
                    quickExportWith(format: .txt)
                }
                Button("As CSV (.csv)") {
                    quickExportWith(format: .csv)
                }
                Button("As JSON (.json)") {
                    quickExportWith(format: .json)
                }
            }
        } label: {
            Label("Export", systemImage: "square.and.arrow.up")
                .font(.system(size: 11))
        }
        .menuStyle(.borderlessButton)
        .disabled(output.isEmpty)
        .alert(alertSuccess ? "Export Successful" : "Export Failed", isPresented: $showingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }
    
    private func exportWith(format: ExportFormat) {
        let data = ExportData(
            title: title,
            timestamp: Date(),
            command: command,
            output: output,
            metadata: metadata
        )
        
        ExportManager.shared.export(data: data, format: format) { success, message in
            if let msg = message {
                alertSuccess = success
                alertMessage = success ? "Saved to: \(msg)" : "Error: \(msg)"
                showingAlert = true
            }
        }
    }
    
    private func quickExportWith(format: ExportFormat) {
        let data = ExportData(
            title: title,
            timestamp: Date(),
            command: command,
            output: output,
            metadata: metadata
        )
        
        let (success, message) = ExportManager.shared.quickExport(data: data, format: format)
        alertSuccess = success
        alertMessage = success ? "Saved to: \(message)" : "Error: \(message)"
        showingAlert = true
    }
}

#Preview {
    ExportButton(
        title: "Ping Results",
        output: "PING google.com: 64 bytes from 142.250.80.46: icmp_seq=0 ttl=117 time=12.3ms",
        command: "ping -c 4 google.com"
    )
    .padding()
}
