// PortScanTests.swift
// STINT — Sev's Tiny Internet Network Tool
// Created by Sevag Bardakjian
// Copyright © 2026 Sevag Bardakjian
// SPDX-License-Identifier: GPL-3.0-only

import XCTest
@testable import STINT

// Probes run against 127.0.0.1 only. The listener is the system's `nc`, so the test never
// asks STINT itself to accept connections (which could raise a firewall prompt).
final class PortScanTests: XCTestCase {

    func testListeningPortIsOpen() async throws {
        let port = Int.random(in: 40_000...59_999)
        let listener = Process()
        listener.executableURL = URL(fileURLWithPath: "/usr/bin/nc")
        listener.arguments = ["-l", "127.0.0.1", String(port)]
        listener.standardOutput = FileHandle.nullDevice
        listener.standardError = FileHandle.nullDevice
        try listener.run()
        defer { listener.terminate() }

        // nc needs a moment to start listening.
        var state = PortState.closed
        for _ in 0..<30 where state != .open {
            state = await checkPort(host: "127.0.0.1", port: port)
            if state != .open { try await Task.sleep(nanoseconds: 100_000_000) }
        }
        XCTAssertEqual(state, .open)
    }

    // A refused connection waits for a retry instead of failing; it used to sit out the
    // full one-second timeout. It should come back closed well before that.
    func testRefusedPortIsClosedQuickly() async {
        let start = Date()
        let state = await checkPort(host: "127.0.0.1", port: 9)  // discard: nothing listens on macOS
        XCTAssertEqual(state, .closed)
        XCTAssertLessThan(Date().timeIntervalSince(start), 0.9)
    }

    // Regression: the state handler and the timeout could both resume the same continuation
    // from different threads, which crashes. Many concurrent probes exercise that race.
    func testManyConcurrentProbesEachReportOnce() async {
        let ports = Array(20_000..<20_300)
        let results = await withTaskGroup(of: PortState.self) { group -> [PortState] in
            for port in ports {
                group.addTask { await checkPort(host: "127.0.0.1", port: port) }
            }
            var all: [PortState] = []
            for await state in group { all.append(state) }
            return all
        }
        XCTAssertEqual(results.count, ports.count)
    }
}
