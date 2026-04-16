import Foundation

class CommandRunner: ObservableObject {
    @Published var output: String = ""
    @Published var isRunning: Bool = false
    
    private var process: Process?
    private var outputPipe: Pipe?
    
    func run(command: String, arguments: [String]) {
        stop()
        
        isRunning = true
        output = ""
        
        let process = Process()
        self.process = process
        
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        
        let pipe = Pipe()
        self.outputPipe = pipe
        process.standardOutput = pipe
        process.standardError = pipe
        
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let str = String(data: data, encoding: .utf8), !str.isEmpty {
                DispatchQueue.main.async {
                    self?.output += str
                }
            }
        }
        
        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.isRunning = false
            }
        }
        
        do {
            try process.run()
        } catch {
            DispatchQueue.main.async {
                self.output = "Error: \(error.localizedDescription)"
                self.isRunning = false
            }
        }
    }
    
    func stop() {
        process?.terminate()
        process = nil
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        outputPipe = nil
        isRunning = false
    }
}

// Synchronous command runner for simple commands
func runCommand(_ command: String, arguments: [String]) -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: command)
    process.arguments = arguments
    
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    
    do {
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    } catch {
        return "Error: \(error.localizedDescription)"
    }
}
