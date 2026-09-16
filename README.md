# Menu Dot

A native Swift menu bar manager for macOS 27. Keep separate Main and Secondary groups and switch between them by clicking the menu bar dot.

## Build and run

```sh
./scripts/run.sh
```

`run.sh` builds, installs into `/Applications/Menu Dot.app`, and launches it. Updating a running copy quits it normally first, restoring all icons. `build.sh` alone only creates the build artifact.

Run the installed copy. On this macOS 27 build, the exact same native status item disappears under a visibility restriction when launched from the project folder, `/tmp`, or `~/Applications`, but stays visible from `/Applications`. AppKit and SwiftUI registration both showed this location-dependent behavior. The sandboxed menu bar host's owner lookup is the suspected cause; the location workaround was verified directly.

The build uses the installed Swift command-line tools, creates a local app, and signs it with a persistent local development certificate. The signing key lives in a separate private keychain under `~/Library/Application Support/BartenderPrototype/Signing`. The build does not change certificate trust or the default keychain. No external packages are required. You can also open `Package.swift` in Xcode.

## Choose your icons

1. The app opens paused, with your menu bar restored.
2. Click **Detect menu bar icons…** and enable **Menu Dot** in macOS Accessibility settings. Return to the app and click Refresh if needed. Switching from an older ad-hoc build may require one fresh approval. Subsequent builds reuse the same certificate and designated requirement.
3. Assign detected icons to **Main**, **Secondary**, **Both**, or **Always hidden**.
4. Press **Start switching**. Click its centered menu bar dot to switch bars.

Main and Secondary replace each other. Both keeps an icon visible in either bar. Always hidden appears in neither group. Clock, Control Center, and Menu Dot's own menu bar button are always included in the allowlist. Clock and Control Center cannot be assigned to a group.

The app has no Dock icon. Right-click the dot for Settings, switching, Restore all icons, or Quit. Settings is also available with Command-comma while its window is active. When paused, clicking the dot opens settings. Reopening the app also brings settings back, providing a recovery path if the dot is unavailable.

**Restore all icons** stops the session without forgetting choices. Escape in settings does the same. Every launch starts paused. Quitting or putting the Mac to sleep also releases the visibility session.

## If Accessibility stays disabled after approval

First quit and reopen the same build. If macOS still denies access, reset only this prototype's stale approval:

```sh
tccutil reset Accessibility dev.dk.BartenderPrototype
```

Then click Detect menu bar icons and grant fresh access in macOS settings. Reopen the same binary if necessary. This does not reset other apps' permissions or delete icon groups. Keep the signing identity in place so future rebuilds retain the same identity.

## New icons

**New menu bar icons** selects the default group for future discoveries, including Both, Secondary, or Always hidden. Existing choices do not change when this default changes.

The first successful inventory treats existing unassigned icons as Main and preserves saved choices from the earlier prototype. Later first-time discoveries receive the configured default. Assignments are saved per owner, so an app returning after a restart keeps its group. Multiple icons belonging to the same app share that app's group.

Discovery checks every five seconds while settings are open or switching is active. It also refreshes after app launches, exits, and bar switches. A new icon can briefly be visible before it is detected and assigned. When paused with settings closed, no menu bar scans run.

## A shorter, more useful list

The app reads the macOS menu bar host's Accessibility item tree. It does not use the running-process list as the icon inventory. Previously detected icons remain editable when hidden or temporarily absent. Earlier saved choices that have never been verified as menu bar icons are kept in a collapsed section.

The image beside an entry is its owning app's artwork, not a screenshot of the menu bar glyph. An icon exposed by a nested helper uses the parent app's name and shows the helper in its description. Multiple icons from one owner appear as one entry because the hiding API controls them together.

Accessibility access is needed for detection. The implementation reads menu bar item owners and labels, and does not traverse app document or window trees. It does not synthesize clicks, request Screen Recording, or capture icon images. Without access, saved groups still switch. Discovering new icons and assigning their default group waits for Accessibility access.

## macOS 27 limits and recovery

Hiding uses an undocumented `MenuBarClientCore` API resolved at runtime. If it is unavailable, switching is disabled. An activation error or a three-second response timeout releases the session.

- Visibility is controlled per app bundle identifier, not per individual icon.
- Only system controls actually detected in the menu bar are listed. Main does not enable a control disabled in macOS settings.
- Some Apple controls are outside the API's supported identifiers and can disappear while switching is active. Restore all icons or quit to release the session.
- macOS controls available space, the notch, and overflow. This prototype switches the original menu bar items inline; it does not create a second row or rearrange icons.
- Accessibility behavior can change between macOS builds. Detection reports failures instead of falling back to a list of unrelated processes.

The prototype does not register for login, change another app's preferences, or restart system processes. Its own settings live in `dev.dk.BartenderPrototype`. This internal identifier, status-item autosave name, and local signing identity retain their original names to preserve existing choices, menu bar placement, and Accessibility approval.

The visibility assertion belongs to the process. macOS is expected to release it on process exit, and the app explicitly invalidates it on normal quit. If it stops responding, force quit **Menu Dot**. The hiding mechanism does not write permanent menu bar configuration.

## Code ownership

- `MenuDotApp.swift`: AppKit lifecycle, menu bar button and menu, settings window.
- `AppModel.swift`: saved choices, new-icon default, discovery scheduling, current group.
- `MenuBarDiscovery.swift`: bounded Accessibility snapshots on a background actor.
- `VisibilityRules.swift`: group membership and default assignment.
- `MenuBarVisibility.swift`: private API boundary and visibility-session lifetime.
- `SettingsView.swift`: native SwiftUI settings. Closing settings releases its view hierarchy.

There is no network client, screen capture, helper daemon, global input monitor, or third-party dependency. Discovery snapshots have short AX messaging timeouts and a two-second work budget. Identical snapshots do not rewrite preferences or recreate list entries.

## Validation

```sh
./scripts/test.sh
```

Three standalone Swift tests protect separate bar membership, always-hidden exclusion, recovery controls, first inventory behavior, and new defaults that preserve existing assignments. They work with the command-line tools without XCTest or Swift Testing plugins.

The current prototype has been compiled; the latest rule-test changes have not been run. Accessibility approval has survived subsequent signed rebuilds. Installing the unchanged signed app in `/Applications` preserved its native dot in Main and Secondary, and manual use confirmed switching works. The app opens paused, with settings available for recovery.

The underlying private API was tested in the first prototype with a bounded runtime smoke test: macOS accepted hide and reveal configurations, then the test invalidated its assertion and exited successfully. `scripts/VisibilitySmoke.swift` and `scripts/MenuBarFixture.swift` remain optional developer diagnostics. Neither runs during normal builds or rule tests.

## Platform references

- [Apple: Application reopen events](https://developer.apple.com/documentation/appkit/nsapplicationdelegate/applicationshouldhandlereopen(_:hasvisiblewindows:))
- [Hidden Bar architecture and macOS 27 limitations](https://github.com/dwarvesf/hidden/blob/develop/docs/ARCHITECTURE.md)
- [Pelmet's macOS 27 API research](https://github.com/fif7y/pelmet)
- [Thaw's macOS 27 limitations](https://github.com/thaw-app/Thaw/releases/tag/3.0.0-alpha.5)

External projects informed the platform research. This prototype has its own Swift implementation and does not include their source code or dependencies.
