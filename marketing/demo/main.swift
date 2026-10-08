// Renders STINT's tools offscreen, in dark mode, at 2x, to PNGs (see ../render.sh).
import AppKit
import SwiftUI

let outDir = CommandLine.arguments[1]
UserDefaults.standard.set("1.1.1.1", forKey: "defaultPingHost")
UserDefaults.standard.set(40, forKey: "defaultPingCount")

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
app.appearance = NSAppearance(named: .darkAqua)
app.finishLaunching()

func render<V: View>(_ view: V, name: String, size: NSSize? = nil) {
    let host = NSHostingView(rootView: view.environment(\.colorScheme, .dark))
    host.appearance = NSAppearance(named: .darkAqua)
    let frameSize = size ?? host.fittingSize
    let window = NSWindow(contentRect: NSRect(origin: .zero, size: frameSize),
                          styleMask: [.borderless], backing: .buffered, defer: false)
    window.appearance = NSAppearance(named: .darkAqua)
    window.contentView = host
    window.setFrameOrigin(NSPoint(x: -30000, y: -30000))
    window.orderFrontRegardless()
    RunLoop.main.run(until: Date().addingTimeInterval(2.5))  // let views load and lay out

    let bounds = host.bounds
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(bounds.width * 2), pixelsHigh: Int(bounds.height * 2),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = bounds.size
    host.cacheDisplay(in: bounds, to: rep)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
    window.orderOut(nil)
    print(name, Int(bounds.width), "x", Int(bounds.height))
}

let windowSize = NSSize(width: 750, height: 520)
render(ContentView(selectedTool: .ping), name: "ping", size: windowSize)
render(ContentView(selectedTool: .info), name: "info", size: windowSize)
render(ContentView(selectedTool: .portScan), name: "port-scan", size: windowSize)
render(ContentView(selectedTool: .traceroute), name: "traceroute", size: windowSize)
render(ContentView(selectedTool: .lookup), name: "lookup", size: windowSize)
render(ContentView(selectedTool: .bonjour), name: "bonjour", size: windowSize)
render(MenuBarWidget().background(Color(NSColor.windowBackgroundColor)), name: "menu-bar")
