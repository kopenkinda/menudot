import AppKit
import ApplicationServices

struct DetectedMenuItem: Sendable {
    let key: String
    let name: String
    let detail: String
    let iconPath: String?
}

struct MenuBarSnapshot: Sendable {
    let items: [DetectedMenuItem]
    let error: String?
}

/// Reads only the menu bar host's item groups, never an app's document/window tree.
/// AX calls can stall, so discovery runs on its own actor with short per-call timeouts.
actor MenuBarDiscovery {
    private var deadline = 0.0
    private var exceededBudget = false
    func snapshot() -> MenuBarSnapshot {
        guard AXIsProcessTrusted() else {
            return MenuBarSnapshot(items: [], error: "Allow Accessibility access to detect menu bar icons.")
        }
        guard let agent = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.MenuBarAgent").first else {
            return MenuBarSnapshot(items: [], error: "The macOS menu bar is not available yet.")
        }
        let root = AXUIElementCreateApplication(agent.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 0.15)
        guard let windows = attribute(root, kAXChildrenAttribute) as? [AXUIElement] else {
            return MenuBarSnapshot(items: [], error: "Could not read the menu bar. Check Accessibility access and try Refresh.")
        }
        deadline = ProcessInfo.processInfo.systemUptime + 2
        exceededBudget = false
        var found: [String: DetectedMenuItem] = [:]
        // Multiple displays can expose duplicate groups. Group by the API's visibility owner.
        for window in windows.prefix(16) {
            for group in children(window).prefix(200) {
                inspect(group, agentPID: agent.processIdentifier, depth: 0, found: &found)
            }
        }
        if exceededBudget { return MenuBarSnapshot(items: [], error: "Menu bar detection took too long. Try Refresh.") }
        return MenuBarSnapshot(items: found.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }, error: nil)
    }

    private func inspect(_ element: AXUIElement, agentPID: pid_t, depth: Int,
                         found: inout [String: DetectedMenuItem]) {
        guard depth <= 3 else { return }
        guard ProcessInfo.processInfo.systemUptime < deadline else { exceededBudget = true; return }
        if let identifier = attribute(element, kAXIdentifierAttribute) as? String,
           let system = Self.systemItems.first(where: { $0.identifiers.contains(identifier) }) {
            let key = "system:\(system.number)"
            guard !VisibilityRules.isProtected(key) else { return }
            found[key] = DetectedMenuItem(key: key, name: system.name, detail: "macOS control", iconPath: nil)
            return
        }
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        if pid > 0, pid != agentPID {
            guard let app = NSRunningApplication(processIdentifier: pid),
                  let id = app.bundleIdentifier, id != Bundle.main.bundleIdentifier else { return }
            if id == "com.apple.TextInputMenuAgent" {
                found["system:4"] = DetectedMenuItem(key: "system:4", name: "Input menu", detail: "macOS control", iconPath: nil)
                return
            }
            if VisibilityRules.isProtected("app:\(id)") { return }
            var ownerURL = app.bundleURL
            var ancestor = app.bundleURL?.deletingLastPathComponent()
            while let current = ancestor, current.path != "/" {
                if current.pathExtension == "app" { ownerURL = current }
                ancestor = current.deletingLastPathComponent()
            }
            let helperName = app.localizedName ?? id
            let name = id == "com.apple.SystemUIServer" ? "Siri and Time Machine"
                : (ownerURL != app.bundleURL ? ownerURL?.deletingPathExtension().lastPathComponent : app.localizedName) ?? id
            let label = [kAXDescriptionAttribute, kAXTitleAttribute].compactMap {
                attribute(element, $0) as? String
            }.first { !$0.isEmpty && $0 != name && $0 != "menu bar item" }
            let key = "app:\(id)"
            if found[key] == nil {
                found[key] = DetectedMenuItem(key: key, name: name,
                    detail: name != helperName ? "Icon provided by \(helperName)" : (label ?? "Menu bar icon"), iconPath: ownerURL?.path)
            }
            // Do not descend into the hosted application's accessibility tree.
            return
        }
        for child in children(element).prefix(100) {
            inspect(child, agentPID: agentPID, depth: depth + 1, found: &found)
        }
    }

    private func children(_ element: AXUIElement) -> [AXUIElement] {
        attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
    }

    private func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(element, name as CFString, &value)
        return value
    }

    private struct SystemItem {
        let number: Int
        let name: String
        let identifiers: [String]
    }
    private static let systemItems: [SystemItem] = [
        .init(number: 0, name: "Battery", identifiers: ["com.apple.menuextra.battery"]),
        .init(number: 1, name: "Bluetooth", identifiers: ["com.apple.menuextra.bluetooth"]),
        .init(number: 2, name: "Clock", identifiers: ["com.apple.menuextra.clock"]),
        .init(number: 3, name: "Displays", identifiers: ["com.apple.menuextra.displays", "com.apple.menuextra.display"]),
        .init(number: 4, name: "Input menu", identifiers: ["com.apple.menuextra.textinput", "com.apple.menuextra.keyboard"]),
        .init(number: 5, name: "Sound", identifiers: ["com.apple.menuextra.volume", "com.apple.menuextra.sound"]),
        .init(number: 6, name: "Wi-Fi", identifiers: ["com.apple.menuextra.wifi"]),
        .init(number: 7, name: "Screen mirroring", identifiers: ["com.apple.menuextra.airplay", "com.apple.menuextra.screen-mirroring"])
    ]
}
