// Styles.swift
// STINT — Sev's Tiny Internet Network Tool
// Created by Sevag Bardakjian
// Copyright © 2026 Sevag Bardakjian
// SPDX-License-Identifier: GPL-3.0-only

import SwiftUI

// Custom styled container with better contrast
struct StyledBox<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
            )
    }
}

// Output text area with monospace font and scroll
struct OutputArea: View {
    let text: String
    let placeholder: String
    
    var body: some View {
        ScrollView {
            Text(text.isEmpty ? placeholder : text)
                .font(.system(size: 11, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(text.isEmpty ? .secondary : .primary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
    }
}

// Scrolling output area that auto-scrolls to bottom
struct ScrollingOutputArea: View {
    let text: String
    let placeholder: String
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(text.isEmpty ? placeholder : text)
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundColor(text.isEmpty ? .secondary : .primary)
                    .id("outputEnd")
            }
            .onChange(of: text) { _ in
                withAnimation(.easeOut(duration: 0.1)) {
                    proxy.scrollTo("outputEnd", anchor: .bottom)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
    }
}

// Radio button style
struct RadioButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isSelected ? "circle.inset.filled" : "circle")
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(.plain)
    }
}

// Status indicator
struct StatusRow: View {
    let isRunning: Bool
    let message: String
    let onStop: () -> Void
    
    var body: some View {
        HStack {
            if isRunning {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 16, height: 16)
            }
            Text(message)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            Spacer()
            
            if isRunning {
                Button("Stop") {
                    onStop()
                }
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
}

// MARK: - Liquid Glass helpers
//
// macOS 26 (Tahoe) introduced the Liquid Glass material. These helpers adopt it on
// 26+ and fall back to the prior styling on older systems, so the macOS 13 deployment
// target still compiles. Glass is applied to the control layer (tabs, buttons) only —
// per Apple's HIG, content-heavy areas (the output panels) stay solid for legibility.

extension View {
    /// Liquid Glass button style on macOS 26+, default styling otherwise.
    @ViewBuilder
    func glassActionButton() -> some View {
        if #available(macOS 26.0, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self
        }
    }
}

// Reusable chrome for the simple "type an address, run a command, show output" tools
// (Whois, Finger, Traceroute). Tools with bespoke option controls — Ping, Lookup,
// Netstat — intentionally keep their own views rather than forcing a leaky abstraction.
struct AddressCommandTool: View {
    let hint: String
    let example: String
    let buttonTitle: String
    let placeholder: String
    let runningMessage: String
    let exportPrefix: String
    let commandPath: String
    let makeArguments: (String) -> [String]
    let commandDescription: (String) -> String
    var scrolling: Bool = false
    var runningPreamble: String? = nil
    var fieldWidth: CGFloat = 250
    var buttonWidth: CGFloat = 60

    @StateObject private var runner = CommandRunner()
    @State private var address: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(hint)
                .font(.system(size: 12))
                .padding(.top, 16)
                .padding(.horizontal, 20)

            HStack {
                TextField("", text: $address)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: fieldWidth)

                Text(example)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Spacer()

                ExportButton(
                    title: "\(exportPrefix)_\(address.isEmpty ? "results" : address)",
                    output: runner.output,
                    command: commandDescription(address)
                )

                Button(action: run) {
                    Text(buttonTitle)
                        .frame(width: buttonWidth)
                }
                .disabled(address.isEmpty || runner.isRunning)
                .keyboardShortcut(.return, modifiers: [])
                .glassActionButton()
            }
            .padding(.horizontal, 20)

            Group {
                if scrolling {
                    ScrollingOutputArea(text: runner.output, placeholder: placeholder)
                } else {
                    OutputArea(text: runner.output, placeholder: placeholder)
                }
            }
            .padding(.horizontal, 20)

            if runner.isRunning {
                StatusRow(isRunning: true, message: runningMessage) {
                    runner.stop()
                }
            } else {
                Spacer().frame(height: 32)
            }
        }
        .padding(.bottom, 12)
        .onDisappear { runner.stop() }
    }

    private func run() {
        if let preamble = runningPreamble {
            runner.output = preamble
        }
        runner.run(command: commandPath, arguments: makeArguments(address))
    }
}
