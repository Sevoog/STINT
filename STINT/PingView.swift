// PingView.swift
// STINT — Sev's Tiny Internet Network Tool
// Created by Sevag Bardakjian
// Copyright © 2026 Sevag Bardakjian
// SPDX-License-Identifier: GPL-3.0-only

import SwiftUI
import Charts

// A single ping result in sequence order. `latency` is nil for a lost/timed-out packet.
struct PingSample: Identifiable {
    let id: Int
    let latency: Double?
}

// Parse streamed `ping` output into ordered samples. Internal so STINTTests can reach it.
func parsePingSamples(_ output: String) -> [PingSample] {
    var result: [PingSample] = []
    var seq = 0
    for line in output.components(separatedBy: "\n") {
        if let range = line.range(of: "time=") {
            let digits = line[range.upperBound...].prefix { $0.isNumber || $0 == "." }
            if let ms = Double(digits) {
                result.append(PingSample(id: seq, latency: ms))
                seq += 1
            }
        } else if line.localizedCaseInsensitiveContains("Request timeout") {
            result.append(PingSample(id: seq, latency: nil))
            seq += 1
        }
    }
    return result
}

struct PingView: View {
    @StateObject private var runner = CommandRunner()
    @AppStorage("defaultPingHost") private var defaultPingHost = "8.8.8.8"
    @AppStorage("defaultPingCount") private var defaultPingCount = 10
    @State private var address: String = ""
    @State private var pingCount: String = ""
    @State private var unlimitedPings: Bool = false
    @State private var showChart: Bool = false
    @State private var samples: [PingSample] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Enter the network address to ping.")
                .font(.system(size: 12))
                .padding(.top, 16)
                .padding(.horizontal, 20)

            HStack {
                TextField("", text: $address)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)

                Text("(ex. 10.0.2.1 or www.example.com)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding(.horizontal, 20)

            RadioButton(title: "Send an unlimited number of pings", isSelected: unlimitedPings) {
                unlimitedPings = true
            }
            .padding(.horizontal, 20)

            HStack(spacing: 8) {
                RadioButton(title: "Send only", isSelected: !unlimitedPings) {
                    unlimitedPings = false
                }

                TextField("", text: $pingCount)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 50)
                    .disabled(unlimitedPings)

                Text("pings")
                    .font(.system(size: 12))

                Spacer()

                ExportButton(
                    title: "Ping_\(address.isEmpty ? "results" : address)",
                    output: runner.output,
                    command: "ping \(unlimitedPings ? "" : "-c \(pingCount) ")\(address)"
                )

                Button(action: runPing) {
                    Text("Ping")
                        .frame(width: 50)
                }
                .disabled(address.isEmpty || runner.isRunning)
                .keyboardShortcut(.return, modifiers: [])
                .glassActionButton()
            }
            .padding(.horizontal, 20)

            // Chart / Text view toggle
            HStack {
                Spacer()
                Picker("", selection: $showChart) {
                    Text("Chart").tag(true)
                    Text("Text").tag(false)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 130)
            }
            .padding(.horizontal, 20)

            Group {
                if showChart {
                    PingChartView(samples: samples)
                } else {
                    ScrollingOutputArea(text: runner.output, placeholder: "")
                }
            }
            .padding(.horizontal, 20)

            if runner.isRunning {
                StatusRow(isRunning: true, message: "Ping has started...") {
                    runner.stop()
                }
            } else {
                Spacer().frame(height: 32)
            }
        }
        .padding(.bottom, 12)
        .onAppear {
            if address.isEmpty { address = defaultPingHost }
            if pingCount.isEmpty { pingCount = String(defaultPingCount) }
        }
        .onDisappear { runner.stop() }
        .onChange(of: runner.output) { newValue in
            samples = parsePingSamples(newValue)
        }
    }

    private func runPing() {
        samples = []
        var args: [String] = []

        if !unlimitedPings {
            // An unparseable count used to fall through to an unlimited ping.
            guard let count = Int(pingCount.trimmingCharacters(in: .whitespaces)), count > 0 else {
                runner.output = "Enter a ping count of 1 or more, or choose unlimited pings.\n"
                return
            }
            args.append("-c")
            args.append(String(count))
        }

        args.append(address)

        runner.output = "Ping has started...\n\n"
        runner.run(command: "/sbin/ping", arguments: args)
    }
}

// MARK: - Chart

struct PingChartView: View {
    let samples: [PingSample]

    // Stats reflect the whole session; the chart shows a rolling window.
    private var latencies: [Double] { samples.compactMap { $0.latency } }
    private var lossCount: Int { samples.filter { $0.latency == nil }.count }
    private var current: Double? { samples.last?.latency }
    private var lossPct: Int {
        samples.isEmpty ? 0 : Int((Double(lossCount) / Double(samples.count) * 100).rounded())
    }
    private var shown: [PingSample] { Array(samples.suffix(60)) }
    private var shownReceived: [PingSample] { shown.filter { $0.latency != nil } }
    private var shownLosses: [PingSample] { shown.filter { $0.latency == nil } }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                statTile("Current", current.map(format) ?? "—", "ms", .accentColor)
                statTile("Min", latencies.min().map(format) ?? "—", "ms", .primary)
                statTile("Avg", latencies.isEmpty ? "—" : format(latencies.reduce(0, +) / Double(latencies.count)), "ms", .primary)
                statTile("Max", latencies.max().map(format) ?? "—", "ms", .primary)
                statTile("Loss", "\(lossPct)", "%", lossPct > 0 ? .orange : .green)
            }

            chartBody
        }
    }

    @ViewBuilder
    private var chartBody: some View {
        Group {
            if samples.isEmpty {
                VStack {
                    Spacer()
                    Text("Run a ping to see live latency.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                Chart {
                    ForEach(shownReceived) { s in
                        AreaMark(
                            x: .value("Seq", s.id),
                            y: .value("ms", s.latency ?? 0)
                        )
                        .foregroundStyle(
                            .linearGradient(
                                colors: [Color.accentColor.opacity(0.35), Color.accentColor.opacity(0.02)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.monotone)

                        LineMark(
                            x: .value("Seq", s.id),
                            y: .value("ms", s.latency ?? 0)
                        )
                        .foregroundStyle(Color.accentColor)
                        .interpolationMethod(.monotone)
                    }

                    ForEach(shownReceived) { s in
                        PointMark(
                            x: .value("Seq", s.id),
                            y: .value("ms", s.latency ?? 0)
                        )
                        .foregroundStyle((s.latency ?? 0) > 30 ? Color.orange : Color.accentColor)
                        .symbolSize(18)
                    }

                    ForEach(shownLosses) { s in
                        PointMark(
                            x: .value("Seq", s.id),
                            y: .value("ms", 0)
                        )
                        .foregroundStyle(Color.red)
                        .symbolSize(28)
                    }
                }
                .chartYScale(domain: .automatic(includesZero: true))
                .chartXAxis(.hidden)
                .chartYAxisLabel("ms", position: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
    }

    private func format(_ v: Double) -> String { String(format: "%.1f", v) }

    private func statTile(_ label: String, _ value: String, _ unit: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, design: .monospaced))
                    .foregroundColor(color)
                Text(unit)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
    }
}

#Preview {
    PingView()
}
