#!/bin/zsh
set -eu
cd "${0:A:h:h}"
./scripts/build.sh

# On this macOS 27 build, the menu bar host preserves our allowed status item
# only when the app runs from /Applications, not the project or ~/Applications.
app="/Applications/Menu Dot.app"
legacy="/Applications/Bartender Prototype.app"
for existing in "$app" "$legacy"; do
    if [[ -e "$existing" ]]; then
        identifier="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$existing/Contents/Info.plist")"
        [[ "$identifier" == "dev.dk.BartenderPrototype" ]] || { print -u2 'A different app occupies the install path.'; exit 1; }
    fi
done
staging="$(mktemp -d /Applications/.MenuDot.XXXXXX)"
trap 'rm -rf "$staging"' EXIT
ditto 'build/Menu Dot.app' "$staging/Menu Dot.app"
codesign --verify --strict "$staging/Menu Dot.app"

# Normal termination restores icons before replacing the installed bundle.
swift -e '
import AppKit
let apps = NSRunningApplication.runningApplications(withBundleIdentifier: "dev.dk.BartenderPrototype")
for app in apps { app.terminate() }
let deadline = Date().addingTimeInterval(5)
while apps.contains(where: { !$0.isTerminated }) && Date() < deadline {
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
}
if apps.contains(where: { !$0.isTerminated }) {
    fputs("Quit Menu Dot before installing the update.\n", stderr)
    exit(1)
}
'
if [[ -d "$app" ]]; then mv "$app" "$staging/previous.app"; fi
if [[ -d "$legacy" ]]; then mv "$legacy" "$staging/legacy.app"; fi
mv "$staging/Menu Dot.app" "$app"
open "$app"
