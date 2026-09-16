import AppKit
import ApplicationServices
import Observation

struct AppEntry: Identifiable {
    let id: String
    let name: String
    let detail: String
    let icon: NSImage?
    let detected: Bool
    let confirmed: Bool
}

@MainActor @Observable
final class AppModel {
    static let ownID = Bundle.main.bundleIdentifier ?? "dev.dk.BartenderPrototype"
    var rules: VisibilityRules
    var apps: [AppEntry] = []
    var search = ""
    var active = false
    var revealed = false
    var applying = false
    var scanning = false
    var settingsVisible = false
    var accessibilityAllowed = AXIsProcessTrusted()
    var discoveryMessage: String?
    var error: String?
    var defaultGroup: Visibility
    var onChange: (() -> Void)?
    private let backend = MenuBarVisibility()
    private let discovery = MenuBarDiscovery()
    private let defaults = UserDefaults.standard
    private var runningIDs: Set<String> = []
    private var lastDetected: Set<String> = []
    private var metadata: [String: [String: String]]
    private var update: DispatchWorkItem?
    private var discoveryTimer: Timer?

    var available: Bool { backend.isAvailable }
    var status: String {
        if applying { return "Switching…" }
        if !active { return "Paused. All icons are restored." }
        return revealed ? "Secondary bar" : "Main bar"
    }

    init() {
        let saved = defaults.dictionary(forKey: "visibilityRules") as? [String: String] ?? [:]
        rules = VisibilityRules(assignments: saved.compactMapValues(Visibility.init(rawValue:)))
        defaultGroup = Visibility(rawValue: defaults.string(forKey: "newIconGroup") ?? "") ?? .visible
        metadata = defaults.dictionary(forKey: "detectedIcons") as? [String: [String: String]] ?? [:]
        // Discard earlier assignments for system-owned controls, including old metadata.
        rules.assignments = rules.assignments.filter { !VisibilityRules.isProtected($0.key) }
        metadata = metadata.filter { !VisibilityRules.isProtected($0.key) }
        defaults.set(rules.assignments.mapValues(\.rawValue), forKey: "visibilityRules")
        defaults.set(metadata, forKey: "detectedIcons")
        rebuildEntries(detected: [])
        refreshApps()
        // The menu bar host does not reliably publish item-change notifications on every
        // macOS 27 build. A small background snapshot catches icons added by existing apps.
        discoveryTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.active || self.settingsVisible else { return }
                self.refreshApps()
            }
        }
        discoveryTimer?.tolerance = 1
    }

    func requestDiscoveryAccess() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refreshApps()
    }

    func refreshApps() {
        runningIDs = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        accessibilityAllowed = AXIsProcessTrusted()
        guard accessibilityAllowed else {
            discoveryMessage = "Saved groups still work. Allow Accessibility access to detect new menu bar icons."
            rebuildEntries(detected: [])
            return
        }
        guard !scanning else { return }
        scanning = true
        Task { [weak self, discovery] in
            let snapshot = await discovery.snapshot()
            guard let self else { return }
            self.scanning = false
            self.discoveryMessage = snapshot.error
            guard snapshot.error == nil else { return }
            let items = snapshot.items.filter { !VisibilityRules.isProtected($0.key) }
            let keys = Set(items.map(\.key))
            let oldAssignments = self.rules.assignments
            let firstScan = !self.defaults.bool(forKey: "hasMenuBarInventory")
            self.rules.register(keys, defaultGroup: self.defaultGroup, firstScan: firstScan)
            // Empty snapshots can occur during menu bar startup. They aren't a baseline.
            if !keys.isEmpty { self.defaults.set(true, forKey: "hasMenuBarInventory") }
            let oldMetadata = self.metadata
            for item in items {
                self.metadata[item.key] = ["name": item.name, "detail": item.detail, "iconPath": item.iconPath ?? ""]
            }
            if oldMetadata != self.metadata { self.defaults.set(self.metadata, forKey: "detectedIcons") }
            if keys != self.lastDetected || oldMetadata != self.metadata || oldAssignments != self.rules.assignments {
                self.lastDetected = keys
                self.rebuildEntries(detected: keys)
            }
            if oldAssignments != self.rules.assignments {
                self.saveRules()
                if self.active { self.apply() }
            }
        }
    }

    private func rebuildEntries(detected: Set<String>) {
        apps = Set(rules.assignments.keys).union(metadata.keys).filter { $0 != "app:\(Self.ownID)" && !VisibilityRules.isProtected($0) }.map { key in
            let data = metadata[key] ?? [:]
            let appID = key.hasPrefix("app:") ? String(key.dropFirst(4)) : ""
            let url = data["iconPath"].flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0) }
                ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: appID)
            let systemNames = ["Battery", "Bluetooth", "Clock", "Displays", "Input menu", "Sound", "Wi-Fi", "Screen mirroring"]
            let systemIndex = key.hasPrefix("system:") ? Int(key.dropFirst(7)) : nil
            let systemName = systemIndex.flatMap { systemNames.indices.contains($0) ? systemNames[$0] : nil }
            let name = data["name"] ?? systemName ?? url?.deletingPathExtension().lastPathComponent ?? key
            return AppEntry(id: key, name: name,
                            detail: data["detail"] ?? "Earlier choice; menu bar icon not confirmed",
                            icon: url.map { NSWorkspace.shared.icon(forFile: $0.path) },
                            detected: detected.contains(key), confirmed: metadata[key] != nil)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func setDefault(_ group: Visibility) {
        defaultGroup = group
        defaults.set(group.rawValue, forKey: "newIconGroup")
    }

    func set(_ visibility: Visibility, for key: String) {
        guard !VisibilityRules.isProtected(key) else { return }
        // Main must be explicit too, so future default changes never move existing icons.
        rules.assignments[key] = visibility
        saveRules()
        if active { apply() }
    }

    private func saveRules() { defaults.set(rules.assignments.mapValues(\.rawValue), forKey: "visibilityRules") }

    func start() {
        active = true
        revealed = false
        apply()
        refreshApps()
    }

    func toggle() {
        guard active else { return }
        revealed.toggle()
        apply()
        refreshApps()
    }

    func restore() {
        update?.cancel()
        update = nil
        backend.restore()
        active = false
        revealed = false
        applying = false
        error = nil
        onChange?()
    }

    func workspaceChanged() {
        update?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.refreshApps()
            if self.active { self.apply() }
        }
        update = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    private func apply() {
        error = nil
        applying = true
        onChange?()
        backend.apply(
            apps: rules.allowedApps(running: runningIDs, ownID: Self.ownID, revealed: revealed),
            systemItems: rules.allowedSystemItems(revealed: revealed)
        ) { [weak self] message in
            guard let self else { return }
            self.applying = false
            if let message {
                self.active = false
                self.revealed = false
                self.error = "Switching stopped: \(message)"
            }
            self.onChange?()
        }
    }
}
