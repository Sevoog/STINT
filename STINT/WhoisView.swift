// WhoisView.swift
// STINT — Sev's Tiny Internet Network Tool
// Created by Sevag Bardakjian
// Copyright © 2026 Sevag Bardakjian
// SPDX-License-Identifier: GPL-3.0-only

import SwiftUI

struct WhoisView: View {
    var body: some View {
        AddressCommandTool(
            hint: "Enter a domain name or IP address to look up.",
            example: "(ex. example.com or 10.0.2.1)",
            buttonTitle: "Whois",
            placeholder: "Enter a domain and click Whois.",
            runningMessage: "Looking up...",
            exportPrefix: "Whois",
            commandPath: "/usr/bin/whois",
            makeArguments: { [$0] },
            commandDescription: { "whois \($0)" }
        )
    }
}

#Preview {
    WhoisView()
}
