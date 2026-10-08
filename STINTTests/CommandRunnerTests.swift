// CommandRunnerTests.swift
// STINT — Sev's Tiny Internet Network Tool
// Created by Sevag Bardakjian
// Copyright © 2026 Sevag Bardakjian
// SPDX-License-Identifier: GPL-3.0-only

import XCTest
@testable import STINT

final class CommandRunnerTests: XCTestCase {

    func testCapturesOutputAndFinishes() {
        let runner = CommandRunner()
        runner.run(command: "/bin/echo", arguments: ["hello from STINT"])
        XCTAssertTrue(waitFor { !runner.isRunning && runner.output.contains("hello from STINT") }, runner.output)
    }

    func testMissingExecutableReportsAnErrorAndCanBeStopped() {
        let runner = CommandRunner()
        runner.run(command: "/nonexistent/tool", arguments: [])
        XCTAssertTrue(waitFor { !runner.isRunning && runner.output.hasPrefix("Error:") }, runner.output)
        runner.stop()  // used to raise: terminate() on a process that never launched
    }

    // Regression: a stopped process finishing after a new run started marked the new run
    // as finished, hiding the Stop button while it kept going.
    func testStoppedRunDoesNotEndTheNextOne() {
        let runner = CommandRunner()
        runner.run(command: "/bin/sleep", arguments: ["30"])
        runner.stop()
        runner.run(command: "/bin/sleep", arguments: ["30"])
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))  // let the first run's termination arrive
        XCTAssertTrue(runner.isRunning)
        runner.stop()
    }

    // Regression: child processes outlive their parent, so an unlimited ping kept running
    // after its tab went away. Releasing the runner must kill its process.
    func testReleasingTheRunnerKillsItsProcess() {
        let tag = String(Int.random(in: 100_000...999_999))  // a sleep length no other process uses
        var runner: CommandRunner? = CommandRunner()
        runner?.run(command: "/bin/sleep", arguments: [tag])
        XCTAssertTrue(waitFor { isSleepRunning(tag) }, "process should start")

        runner = nil
        XCTAssertTrue(waitFor { !isSleepRunning(tag) }, "process should be killed when the runner is released")
    }

    // MARK: - Helpers

    private func waitFor(timeout: TimeInterval = 5, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        return condition()
    }

    private func isSleepRunning(_ tag: String) -> Bool {
        let pgrep = Process()
        pgrep.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        pgrep.arguments = ["-f", "^/bin/sleep \(tag)$"]
        pgrep.standardOutput = FileHandle.nullDevice
        try? pgrep.run()
        pgrep.waitUntilExit()
        return pgrep.terminationStatus == 0
    }
}
