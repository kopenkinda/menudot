# Menu Dot

A small native Swift menu bar manager for macOS 27. Assign icons to Main, Secondary, Both, or Always hidden. No Dock icon, external packages, or background helper. This is a source-only project: build and sign your own copy.

> [!WARNING]
> This application was built entirely with gpt-6-astra. Use it at your own risk.

## Use

- Click the dot to switch between Main and Secondary while started.
- Right-click the dot for Settings and Start or Stop. Stop restores all icons.
- Hold Command and drag menu bar icons to rearrange them using native macOS behavior.
- In Settings, choose the default group for new icons, launch at login, and whether to launch Started or Stopped.

Enable Accessibility when prompted to detect menu bar icons. Icons belonging to the same app move together. Clock and Control Center cannot be hidden.

## Build and sign

Requires macOS 27, Xcode 27, Python 3, and OpenSSL available in your shell. Open Xcode once to finish its setup, then run from the cloned repository:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
./scripts/run.sh
```

This builds, signs, installs into `/Applications/Menu Dot.app`, and launches it. Use `./scripts/build.sh` to build and sign without installing. Run the installed copy: launching from the project folder can cause macOS to hide the app's own dot.

Signing is automatic. The first build creates your own self-signed development certificate in a private keychain under `~/Library/Application Support/MenuDot/Signing`. Later builds reuse it so Accessibility approval can survive updates. Keep that directory private and intact. No paid Apple Developer account or notarization is needed for this local build. The scripts do not change system certificate trust or your default keychain.

The build uses `dev.<username>.menudot` as its app identifier, based on your macOS username.

## macOS limitation

Menu Dot uses an undocumented macOS 27 API. It may change between OS releases, and some Apple controls may disappear while switching is active. Stop or quit Menu Dot to restore them.
