// Runs only when compiled and launched explicitly. Restores within 12 seconds.
import AppKit

@main struct VisibilitySmoke {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let backend = MenuBarVisibility()
        guard backend.isAvailable else { print("Private API unavailable"); exit(1) }
        let fixtureID = "dev.user.menudot.testicon"
        let allowed = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        var failed = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            backend.apply(apps: allowed.subtracting([fixtureID]).sorted(), systemItems: Array(0...8)) { error in
                if let error { failed = true; print("Hide failed: \(error)") }
                else { print("Hide configuration accepted") }
                fflush(stdout)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            backend.apply(apps: allowed.union([fixtureID]).sorted(), systemItems: Array(0...8)) { error in
                if let error { failed = true; print("Reveal failed: \(error)") }
                else { print("Reveal configuration accepted") }
                fflush(stdout)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 9) {
            backend.restore()
            print("Visibility session invalidated")
            fflush(stdout)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 12) {
            backend.restore()
            exit(failed ? 1 : 0)
        }
        withExtendedLifetime(backend) { app.run() }
    }
}
