#!/bin/zsh
set -eu
cd "${0:A:h:h}"
mkdir -p .build
xcrun swiftc -swift-version 5 -parse-as-library -O -module-cache-path .build/ModuleCache Sources/AgentIndicator/*.swift -o .build/AgentIndicator -framework AppKit -framework SwiftUI -framework IOKit -framework CoreGraphics -framework ServiceManagement -framework UserNotifications
app_bundle="$HOME/Applications/Agent Indicator.app"
if [[ -d "/Applications/Agent Indicator.app" ]]; then
    app_bundle="/Applications/Agent Indicator.app"
fi
mkdir -p "$app_bundle/Contents/MacOS"
cp .build/AgentIndicator "$app_bundle/Contents/MacOS/AgentIndicator"
cat > "$app_bundle/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.minchuan.AgentIndicator</string>
<key>CFBundleName</key><string>Agent Indicator</string>
<key>CFBundleDisplayName</key><string>Agent Indicator</string>
<key>CFBundleExecutable</key><string>AgentIndicator</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>27.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - --identifier com.minchuan.AgentIndicator "$app_bundle"
print -r -- "$app_bundle"
