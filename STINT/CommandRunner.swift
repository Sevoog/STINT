// CommandRunner.swift
// STINT — Sev's Tiny Internet Network Tool
// Created by Sevag Bardakjian
// Copyright © 2026 Sevag Bardakjian
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import AppKit

class CommandRunner: ObservableObject {
    @Published var output: String = ""
    @Published var isRunning: Bool = false
    
    private var process: Process?
    private var outputPipe: Pipe?
    private var terminateObserver: NSObjectProtocol?

    init() {
        // Child processes outlive the app unless killed, so an unlimited ping would keep
        // running after STINT quits. Stop whatever is running when the app terminates.
        terminateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.stop()
        }
    }

    deinit {
        // The owning view went away (tab switch, window closed) — don't orphan the process.
        if let terminateObserver { NotificationCenter.default.removeObserver(terminateObserver) }
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        process?.terminate()
    }

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
        
        process.terminationHandler = { [weak self] finished in
            DispatchQueue.main.async {
                // A stopped process can finish after a new run has started; only the
                // current process may clear the running state.
                guard let self, self.process === finished else { return }
                self.isRunning = false
            }
        }
        
        do {
            try process.run()
        } catch {
            // terminate() raises on a process that never launched, so don't keep it.
            self.process = nil
            pipe.fileHandleForReading.readabilityHandler = nil
            self.outputPipe = nil
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
