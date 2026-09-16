import AppKit
import SwiftUI

@main
struct MenuDotApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv) }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var model: AppModel!
    private var statusItem: NSStatusItem!
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Opening another copy brings the existing prototype back to settings.
        if let other = NSRunningApplication.runningApplications(withBundleIdentifier: AppModel.ownID)
            .first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            other.activate()
            NSApp.terminate(nil)
            return
        }
        let mainMenu = NSMenu()
        let appMenu = NSMenu()
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Menu Dot", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        NSApp.mainMenu = mainMenu
        model = AppModel()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.autosaveName = "BartenderPrototype"
        statusItem.isVisible = true
        let dot = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setFill()
            NSBezierPath(ovalIn: NSRect(x: 6, y: 6, width: 6, height: 6)).fill()
            return true
        }
        dot.isTemplate = true
        statusItem.button?.image = dot
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.setAccessibilityLabel("Switch menu bars")
        statusItem.button?.target = self
        statusItem.button?.action = #selector(clicked)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        model.onChange = { [weak self] in self?.updateButton() }
        updateButton()
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            center.addObserver(self, selector: #selector(workspaceChanged), name: name, object: nil)
        }
        center.addObserver(self, selector: #selector(restore), name: NSWorkspace.willSleepNotification, object: nil)
        if model.launchStarted { model.start() }
        showSettings()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if model != nil { showSettings() }
        return false
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        model?.refreshLoginStatus()
    }

    func applicationWillTerminate(_ notification: Notification) {
        model?.restore()
    }

    @objc private func workspaceChanged() { model.workspaceChanged() }

    private func controlsMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let toggleItem = NSMenuItem(title: model.revealed ? "Switch to Main" : "Switch to Secondary",
                                    action: #selector(toggle), keyEquivalent: "")
        toggleItem.target = self
        toggleItem.isEnabled = model.active
        menu.addItem(toggleItem)
        menu.addItem(.separator())
        for (title, action) in [("Settings…", #selector(showSettings)),
                                ("Restore all icons", #selector(restore)),
                                ("Quit Menu Dot", #selector(quit))] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }
        return menu
    }

    private func updateButton() {
        // Keep one template image attached across assertion changes. Only the action
        // description changes; the switch itself never belongs to either group.
        if !statusItem.isVisible { statusItem.isVisible = true }
        statusItem.button?.toolTip = model.active
            ? "Menu Dot: switch to \(model.revealed ? "Main" : "Secondary"); right-click for settings"
            : "Menu Dot is paused. Click to choose icons."
    }

    @objc private func clicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = controlsMenu()
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else if model.active {
            model.toggle()
        } else {
            showSettings()
        }
    }

    func windowWillClose(_ notification: Notification) {
        model.settingsVisible = false
        // Release the settings hierarchy while only the menu bar button is in use.
        DispatchQueue.main.async { [weak self] in
            guard self?.window?.isVisible == false else { return }
            self?.window = nil
        }
    }

    @objc private func toggle() { model.toggle() }
    @objc private func restore() { model.restore() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func showSettings() {
        model.refreshLoginStatus()
        model.settingsVisible = true
        model.refreshApps()
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 630, height: 730),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable],
                                  backing: .buffered, defer: false)
            window.title = "Menu Dot"
            window.delegate = self
            window.contentView = NSHostingView(rootView: SettingsView(model: model))
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
