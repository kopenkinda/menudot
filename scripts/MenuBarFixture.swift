// Manual QA fixture. Compile into a disposable .app; exits after two minutes.
import AppKit

@MainActor final class FixtureDelegate: NSObject, NSApplicationDelegate {
    var item: NSStatusItem!
    func applicationDidFinishLaunching(_ notification: Notification) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "BTEST"
        item.button?.setAccessibilityLabel("Menu Dot test icon")
        let menu = NSMenu()
        menu.addItem(withTitle: "Test icon is working", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "Quit test icon", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        DispatchQueue.main.asyncAfter(deadline: .now() + 120) { NSApp.terminate(nil) }
    }
}

@main struct Fixture {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = FixtureDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
