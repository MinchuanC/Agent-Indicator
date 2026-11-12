#!/bin/zsh
set -eu
cd "${0:A:h:h}"
mkdir -p .build
xcrun swiftc -module-cache-path .build/ModuleCache Sources/LEDProbe/main.swift -o .build/LEDProbe -framework IOKit -framework CoreGraphics
probe_app="$HOME/Applications/Agent Indicator LED Probe.app"
mkdir -p "$probe_app/Contents/MacOS"
cp .build/LEDProbe "$probe_app/Contents/MacOS/LEDProbe"
cat > "$probe_app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.minchuan.AgentIndicator.LEDProbe</string>
<key>CFBundleName</key><string>Agent Indicator LED Probe</string>
<key>CFBundleExecutable</key><string>LEDProbe</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSUIElement</key><true/>
</dict></plist>
PLIST
codesign --force --sign - --identifier com.minchuan.AgentIndicator.LEDProbe "$probe_app"
print -r -- "$probe_app"
