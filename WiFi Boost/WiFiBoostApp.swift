import SwiftUI
import AppKit
import ServiceManagement

@main
struct WiFiBoostApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var keepBoosted = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            updateIcon()
        }

        // Poll every 2 seconds to catch external changes
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkAndUpdate()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
    }

    @objc func handleClick() {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showMenu()
        } else {
            toggleAWDL()
        }
    }

    func showMenu() {
        let menu = NSMenu()

        let isBoosted = !AWDLController.shared.isEnabled()

        // Status
        let statusMenuItem = NSMenuItem(title: isBoosted ? "✓ Wi-Fi Boosted" : "Normal Mode", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Keep Boosted toggle
        let keepItem = NSMenuItem(title: "Keep Boosted (Auto-restore)", action: #selector(toggleKeepBoosted), keyEquivalent: "")
        keepItem.target = self
        keepItem.state = keepBoosted ? .on : .off
        menu.addItem(keepItem)

        // Launch at Login toggle
        let launchItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchItem.target = self
        launchItem.state = isLaunchAtLoginEnabled() ? .on : .off
        menu.addItem(launchItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        self.statusItem.menu = menu
        self.statusItem.button?.performClick(nil)
        self.statusItem.menu = nil
    }

    @objc func toggleKeepBoosted() {
        keepBoosted.toggle()
        if keepBoosted && AWDLController.shared.isEnabled() {
            // If enabling keep-boosted while not boosted, boost now
            AWDLController.shared.setEnabled(false)
            updateIcon()
        }
    }

    @objc func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            print("Failed to toggle launch at login: \(error)")
        }
    }

    func isLaunchAtLoginEnabled() -> Bool {
        return SMAppService.mainApp.status == .enabled
    }

    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }

    @objc func toggleAWDL() {
        let currentlyEnabled = AWDLController.shared.isEnabled()
        AWDLController.shared.setEnabled(!currentlyEnabled)

        // If user manually un-boosts, disable keep-boosted
        if !currentlyEnabled == true {
            keepBoosted = false
        }

        updateIcon()
    }

    func checkAndUpdate() {
        let awdlEnabled = AWDLController.shared.isEnabled()

        // If keep-boosted is on and AWDL got re-enabled, disable it again
        if keepBoosted && awdlEnabled {
            AWDLController.shared.setEnabled(false)
        }

        updateIcon()
    }

    func updateIcon() {
        guard let button = statusItem.button else { return }

        let isBoosted = !AWDLController.shared.isEnabled()

        let symbolName = isBoosted ? "bolt.fill" : "bolt"
        let config = NSImage.SymbolConfiguration(paletteColors: [isBoosted ? .systemGreen : .labelColor])

        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: isBoosted ? "Wi-Fi Boosted" : "Normal Mode") {
            let coloredImage = image.withSymbolConfiguration(config)
            coloredImage?.isTemplate = false
            button.image = coloredImage
        }
    }
}
