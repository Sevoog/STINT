# Frames the raw screenshots from render.sh into 1920x1080 marketing images, using
# frame.html and headless Chrome. Pass page names to rebuild only those.
import os, subprocess, sys, tempfile
S = os.path.dirname(os.path.abspath(__file__))
SRC = f"{S}/screenshots"                  # raw renders (demo data)
OUT = f"{S}/screenshots/framed"
ICON = os.path.abspath(f"{S}/../STINT/Assets.xcassets/AppIcon.appiconset/icon_256x256@2x.png")
tpl = open(f"{S}/frame.html", encoding="utf-8").read()

def window(img): return (f'<div class="shot"><div class="titlebar"><span class="lights"><i></i><i></i><i></i></span>'
                         f'<span class="title">STINT</span></div><img src="file://{SRC}/{img}"></div>')
def panel(img): return f'<div class="shot"><img src="file://{SRC}/{img}"></div>'
def pills(*p): return '<div class="pills">' + "".join(f'<span class="pill">{x}</span>' for x in p) + "</div>"
def copy(h1, sub, *p): return f'<div class="copy"><h1>{h1}</h1><p class="sub">{sub}</p>{pills(*p) if p else ""}</div>'

pages = {
 "01-ping": ("showcase", copy("Network Utility,<br><em>back on your Mac</em>.",
     "Apple's Network Utility is gone. STINT brings back its tools, adds a Bonjour browser, and charts your ping live.",
     "9 tools", "Native Swift", "No dependencies") + window("ping.png")),
 "02-info": ("side", copy("Every interface, <em>at a glance</em>.",
     "Addresses, link speed, vendor and model for each network adapter, named the way System Settings names them, plus transfer statistics.",
     "IPv4 · IPv6 · MAC", "Multi-gig link speeds", "Vendor and model") + window("info.png")),
 "03-port-scan": ("side", copy("Find <em>open ports</em>.",
     "Scan the ports common TCP services use, or any range you choose, 64 at a time with live progress.",
     "Common ports or a range", "Service names", "TXT · CSV · JSON export") + window("port-scan.png")),
 "04-menu-bar": ("menubar", copy("Always <em>one click</em> away.",
     "Connection status, your local IP and a quick ping, right from the menu bar.",
     "Quick ping", "Copy IP address", "Launch at login") + panel("menu-bar.png")),
 "05-traceroute": ("side", copy("See <em>every hop</em>.",
     "Trace the route to any host and watch each hop arrive. Export the result when you need to share it.",
     "Live output", "Stop any time", "TXT · CSV · JSON export") + window("traceroute.png")),
 "06-lookup": ("side", copy("DNS, <em>any record</em>.",
     "Look up A, AAAA, CNAME, MX, NS, PTR, SOA, TXT or ANY records, with Whois, Finger and Netstat close by.",
     "9 query types", "Whois · Finger · Netstat") + window("lookup.png")),
 "07-bonjour": ("side", copy("What's <em>on your network</em>?",
     "Browse Bonjour services: AirPlay, printers, file shares, HomeKit and more, or any custom service type.",
     "20 common types", "Custom types", "Export") + window("bonjour.png")),
}

CH = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
os.makedirs(OUT, exist_ok=True)
only = sys.argv[1:]
for name, (layout, content) in pages.items():
    if only and name not in only: continue
    html = tpl.replace("__LAYOUT__", layout).replace("__CONTENT__", content).replace("__ICON__", f"file://{ICON}")
    tmp = f"{S}/.{name}.html"
    open(tmp, "w", encoding="utf-8").write(html)
    prof = tempfile.mkdtemp()
    out = os.path.abspath(f"{OUT}/{name}.png")
    # --run-all-compositor-stages-before-draw: without it Chrome occasionally captures before
    # the large screenshot has finished drawing, leaving a gray strip along the bottom.
    subprocess.run(["perl", "-e", "alarm 40; exec @ARGV", CH, "--headless=new", "--disable-gpu", "--hide-scrollbars",
                    "--run-all-compositor-stages-before-draw",
                    "--no-first-run", f"--user-data-dir={prof}", "--allow-file-access-from-files",
                    "--window-size=1920,1080", "--force-device-scale-factor=1", "--timeout=4000",
                    f"--screenshot={out}", f"file://{tmp}"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(["rm", "-rf", prof, tmp])
    print(name, os.path.getsize(out) if os.path.exists(out) else "MISSING")
