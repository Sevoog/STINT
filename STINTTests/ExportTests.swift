// ExportTests.swift
// STINT — Sev's Tiny Internet Network Tool
// Created by Sevag Bardakjian
// Copyright © 2026 Sevag Bardakjian
// SPDX-License-Identifier: GPL-3.0-only

import XCTest
@testable import STINT

final class ExportTests: XCTestCase {
    private let sample = ExportData(
        title: "Ping_1.1.1.1",
        timestamp: Date(timeIntervalSince1970: 0),
        command: "ping -c 2 1.1.1.1",
        output: "64 bytes from 1.1.1.1: icmp_seq=0 ttl=57 time=11.8 ms\n\nsay \"hi\"\n",
        metadata: ["host": "1.1.1.1", "count": "2"]
    )

    func testPlainTextHasHeaderCommandSortedMetadataAndOutput() {
        let text = sample.toPlainText()
        XCTAssertTrue(text.hasPrefix("=== Ping_1.1.1.1 ===\n"))
        XCTAssertTrue(text.contains("Command: ping -c 2 1.1.1.1\n"))
        XCTAssertTrue(text.contains("count: 2\nhost: 1.1.1.1\n"), "metadata is sorted by key")
        XCTAssertTrue(text.hasSuffix(sample.output))
    }

    func testCSVHasOneRowPerNonEmptyLineAndEscapesQuotes() {
        let rows = sample.toCSV().split(separator: "\n", omittingEmptySubsequences: true)
        XCTAssertEqual(rows.first, "timestamp,title,data")
        XCTAssertEqual(rows.count, 3, "header plus the two non-empty output lines")
        XCTAssertTrue(rows[2].hasSuffix(##","Ping_1.1.1.1","say ""hi""""##), String(rows[2]))
    }

    func testJSONIsValidAndCarriesEveryField() throws {
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(sample.toJSON().utf8)) as? [String: Any])
        XCTAssertEqual(json["title"] as? String, "Ping_1.1.1.1")
        XCTAssertEqual(json["command"] as? String, "ping -c 2 1.1.1.1")
        XCTAssertEqual(json["output"] as? String, sample.output)
        XCTAssertEqual(json["metadata"] as? [String: String], ["host": "1.1.1.1", "count": "2"])
        XCTAssertNotNil(json["timestamp"] as? String)
    }
}
