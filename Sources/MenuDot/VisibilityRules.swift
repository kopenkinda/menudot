import Foundation

enum Visibility: String, CaseIterable, Codable {
    // Keep stored values compatible with the first prototype.
    case visible, onClick, both, hidden

    var title: String {
        switch self {
        case .visible: "Main"
        case .onClick: "Secondary"
        case .both: "Both"
        case .hidden: "Always hidden"
        }
    }

    func allows(revealed: Bool) -> Bool {
        self == .both || (revealed ? self == .onClick : self == .visible)
    }
}

struct VisibilityRules {
    var assignments: [String: Visibility] = [:]

    static func isProtected(_ key: String) -> Bool {
        ["system:2", "system:8", "app:com.apple.controlcenter", "app:com.apple.menubaragent", "app:com.apple.clock"].contains(key.lowercased())
    }

    mutating func register(_ keys: Set<String>, defaultGroup: Visibility, firstScan: Bool) {
        // The first inventory is the existing bar. Future discoveries use the chosen default.
        for key in keys where !Self.isProtected(key) && assignments[key] == nil {
            assignments[key] = firstScan ? .visible : defaultGroup
        }
    }

    func allowedApps(running: Set<String>, ownID: String, revealed: Bool) -> [String] {
        let allowed = running.union(assignments.keys.compactMap {
            $0.hasPrefix("app:") ? String($0.dropFirst(4)) : nil
        }).filter {
            if Self.isProtected("app:\($0)") { return true }
            // Do not hide unknown processes. Only confirmed menu bar owners get a group.
            guard let group = assignments["app:\($0)"] else { return true }
            return group.allows(revealed: revealed)
        }
        return Set(allowed).union([ownID]).sorted()
    }

    func allowedSystemItems(revealed: Bool) -> [Int] {
        // Clock and Control Center are system-owned and never participate in groups.
        (0..<8).filter {
            if $0 == 2 { return true }
            guard let group = assignments["system:\($0)"] else { return true }
            return group.allows(revealed: revealed)
        } + [8]
    }
}
