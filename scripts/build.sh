#!/bin/zsh
set -eu
cd "${0:A:h:h}"
swift build -c release
mkdir -p "$PWD/build"
staging="$(mktemp -d "$PWD/build/.staging.XXXXXX")"
trap 'rm -rf "$staging"' EXIT
app="$staging/Menu Dot.app"
mkdir -p "$app/Contents/MacOS"
bin_dir="$(swift build -c release --show-bin-path)"
cp "$bin_dir/MenuDot" "$app/Contents/MacOS/MenuDot"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>MenuDot</string>
<key>CFBundleIdentifier</key><string>dev.dk.BartenderPrototype</string>
<key>CFBundleName</key><string>Menu Dot</string>
<key>CFBundleDisplayName</key><string>Menu Dot</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>27.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
python3 scripts/sign.py "$app"
destination="$PWD/build/Menu Dot.app"
if [[ -d "$destination" ]]; then mv "$destination" "$staging/previous.app"; fi
mv "$app" "$destination"
print -r -- "$destination"
