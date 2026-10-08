#!/bin/sh
# Renders each STINT tool with placeholder data into marketing/screenshots/.
# Works on throwaway copies of the sources (patched by demo/patch.py), so the app
# itself has no demo mode. Then run build.py to frame them.
set -e
M="$(cd "$(dirname "$0")" && pwd)"
W="$(mktemp -d)"
trap 'rm -rf "$W"' EXIT

cp "$M/../STINT/"*.swift "$W/"
python3 -I "$M/demo/patch.py" "$W"
cp "$M/demo/main.swift" "$W/main.swift"
# Same deployment target as the app, so the compiler judges the code the way Xcode does.
swiftc -O -target "$(uname -m)-apple-macos13.0" -o "$W/render" "$W"/*.swift
mkdir -p "$M/screenshots"
"$W/render" "$M/screenshots" 2>&1 | grep -v '^Charts:'
