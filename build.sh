#!/bin/zsh
set -e
cd "$(dirname "$0")"
APP="SalaryTicker.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
swiftc -O -swift-version 5 -target arm64-apple-macosx14.0 main.swift -o /tmp/st_arm64
swiftc -O -swift-version 5 -target x86_64-apple-macosx14.0 main.swift -o /tmp/st_x86_64
lipo -create /tmp/st_arm64 /tmp/st_x86_64 -output "$APP/Contents/MacOS/SalaryTicker"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>工资计时器</string>
  <key>CFBundleDisplayName</key><string>工资计时器</string>
  <key>CFBundleIdentifier</key><string>com.owo.salaryticker</string>
  <key>CFBundleExecutable</key><string>SalaryTicker</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force -s - "$APP"
echo "Built $PWD/$APP"
