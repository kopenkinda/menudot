import Foundation

@main struct VisibilityRulesTests {
    static func main() {
        testSwitchingUsesSeparateGroups()
        testSystemChoicesPreserveClockAndControlCenter()
        testNewIconDefaultDoesNotMoveExistingIcons()
        print("Visibility rules: 3 tests passed")
    }

    static func testSwitchingUsesSeparateGroups() {
        let rules = VisibilityRules(assignments: [
            "app:shared": .both, "app:main": .visible, "app:secondary": .onClick, "app:secret": .hidden, "app:self": .hidden
        ])
        let running: Set<String> = ["main", "secondary", "secret", "unknown-process", "self"]
        expectEqual(rules.allowedApps(running: running, ownID: "self", revealed: false),
                    ["main", "self", "shared", "unknown-process"])
        expectEqual(rules.allowedApps(running: running, ownID: "self", revealed: true),
                    ["secondary", "self", "shared", "unknown-process"])
    }

    static func testSystemChoicesPreserveClockAndControlCenter() {
        let rules = VisibilityRules(assignments: ["system:0": .visible, "system:1": .onClick, "system:2": .hidden, "system:8": .hidden])
        expectEqual(rules.allowedSystemItems(revealed: false), [0, 2, 3, 4, 5, 6, 7, 8])
        expectEqual(rules.allowedSystemItems(revealed: true), [1, 2, 3, 4, 5, 6, 7, 8])
    }

    static func testNewIconDefaultDoesNotMoveExistingIcons() {
        var rules = VisibilityRules(assignments: ["app:saved": .hidden])
        rules.register(["app:existing", "app:saved"], defaultGroup: .onClick, firstScan: true)
        expectEqual(rules.assignments["app:existing"], .visible)
        expectEqual(rules.assignments["app:saved"], .hidden)
        rules.register(["app:existing", "app:new"], defaultGroup: .onClick, firstScan: false)
        expectEqual(rules.assignments["app:existing"], .visible)
        expectEqual(rules.assignments["app:new"], .onClick)
        rules.register(["app:new", "system:6"], defaultGroup: .hidden, firstScan: false)
        expectEqual(rules.assignments["app:new"], .onClick)
        expectEqual(rules.assignments["system:6"], .hidden)
        let restored = VisibilityRules(assignments: rules.assignments)
        expectEqual(restored.allowedApps(running: ["existing", "new"], ownID: "self", revealed: true), ["new", "self"])
    }
}

private func expectEqual<T: Equatable>(_ actual: T, _ expected: T) {
    precondition(actual == expected, "Expected \(expected), received \(actual)")
}
