// ParserTests.swift
// STINT — Sev's Tiny Internet Network Tool
// Created by Sevag Bardakjian
// Copyright © 2026 Sevag Bardakjian
// SPDX-License-Identifier: GPL-3.0-only

import XCTest
@testable import STINT

// Parsers that turn system tool output into what the tools display.
final class ParserTests: XCTestCase {

    // MARK: - Ping

    func testPingSamplesKeepRepliesAndTimeoutsInOrder() {
        let output = """
        PING 1.1.1.1 (1.1.1.1): 56 data bytes
        64 bytes from 1.1.1.1: icmp_seq=0 ttl=57 time=11.842 ms
        Request timeout for icmp_seq 1
        64 bytes from 1.1.1.1: icmp_seq=2 ttl=57 time=38.2 ms

        --- 1.1.1.1 ping statistics ---
        3 packets transmitted, 2 packets received, 33.3% packet loss
        round-trip min/avg/max/stddev = 11.842/25.021/38.200/13.179 ms
        """
        let samples = parsePingSamples(output)
        XCTAssertEqual(samples.map(\.id), [0, 1, 2])
        XCTAssertEqual(samples.map(\.latency), [11.842, nil, 38.2])
    }

    func testPingSamplesIgnoreHeadersErrorsAndEmptyOutput() {
        XCTAssertTrue(parsePingSamples("").isEmpty)
        XCTAssertTrue(parsePingSamples("PING example.com (93.184.215.14): 56 data bytes\n").isEmpty)
        XCTAssertTrue(parsePingSamples("ping: cannot resolve nowhere.invalid: Unknown host\n").isEmpty)
    }

    // MARK: - Info: link speed

    func testLinkSpeedFromIfconfigMediaLine() {
        let cases: [(line: String, expected: String?)] = [
            ("media: autoselect (1000baseT <full-duplex,flow-control>)", "1 Gbps"),
            ("media: autoselect (2500Base-T <full-duplex>)", "2.5 Gbps"),
            ("media: autoselect (5000Base-T <full-duplex>)", "5 Gbps"),
            ("media: autoselect (10GbaseT <full-duplex>)", "10 Gbps"),
            ("media: autoselect (100baseTX <full-duplex>)", "100 Mbps"),
            ("media: 10baseT/UTP <half-duplex>", "10 Mbps"),
            // Wi-Fi, Thunderbolt and disconnected ports name no speed.
            ("media: autoselect", nil),
            ("media: autoselect <full-duplex>", nil),
            ("media: autoselect (none)", nil),
        ]
        for (line, expected) in cases {
            XCTAssertEqual(parseLinkSpeed(fromMediaLine: line), expected, line)
        }
    }

    // MARK: - Info: transfer statistics

    func testPacketStatsForInterfaceWithHardwareAddress() {
        let output = """
        Name       Mtu   Network       Address            Ipkts Ierrs     Ibytes    Opkts Oerrs     Obytes  Coll
        en0        1500  <Link#14>   de:ad:be:ef:ca:fe  9179399     2 8932269031  6437628     1 6543078589     3
        """
        let stats = parsePacketStats(netstatOutput: output)
        XCTAssertEqual(stats.received, "9179399")
        XCTAssertEqual(stats.recvErrors, "2")
        XCTAssertEqual(stats.sent, "6437628")
        XCTAssertEqual(stats.sendErrors, "1")
        XCTAssertEqual(stats.collisions, "3")
    }

    // lo0 and VPN tunnels have no MAC, so netstat leaves the Address column blank. Reading
    // columns from the left used to shift every counter and show zeros.
    func testPacketStatsForInterfaceWithoutHardwareAddress() {
        let output = """
        Name       Mtu   Network       Address            Ipkts Ierrs     Ibytes    Opkts Oerrs     Obytes  Coll
        lo0        16384 <Link#1>                      13591331     0 80159876298 13591330     0 80159876298     0
        """
        let stats = parsePacketStats(netstatOutput: output)
        XCTAssertEqual(stats.received, "13591331")
        XCTAssertEqual(stats.sent, "13591330")
        XCTAssertEqual(stats.recvErrors, "0")
        XCTAssertEqual(stats.sendErrors, "0")
        XCTAssertEqual(stats.collisions, "0")
    }

    func testPacketStatsFallBackToZeros() {
        let stats = parsePacketStats(netstatOutput: "netstat: interface nope0 does not exist\n")
        XCTAssertEqual([stats.sent, stats.received, stats.sendErrors, stats.recvErrors, stats.collisions],
                       ["0", "0", "0", "0", "0"])
    }

    // MARK: - Port Scan

    func testServiceNames() {
        XCTAssertEqual(serviceName(for: 22), "ssh")
        XCTAssertEqual(serviceName(for: 443), "https")
        XCTAssertEqual(serviceName(for: 5900), "vnc")
        XCTAssertEqual(serviceName(for: 12345), "unknown")
    }
}
