import AppKit
import SwiftUI
import Combine
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, UNUserNotificationCenterDelegate {
    private var model: AppModel!
    private var item: NSStatusItem!
    private let statusMenu = NSMenu()
    private var settings: NSWindow?
    private var subscriptions = Set<AnyCancellable>()
    func applicationDidFinishLaunching(_ notification: Notification) {
        if NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier!).count > 1 { NSApp.terminate(nil); return }
        NSApp.setActivationPolicy(.accessory)
        model = AppModel()
        UNUserNotificationCenter.current().delegate = self
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusMenu.delegate = self
        item.menu = statusMenu
        model.objectWillChange.sink { [weak self] in DispatchQueue.main.async { self?.updateIcon() } }.store(in: &subscriptions)
        installMenus()
        model.start(); updateIcon()
        model.$actionError.compactMap { $0 }.sink { [weak self] message in
            DispatchQueue.main.async {
                self?.model.actionError = nil
                let alert = NSAlert(); alert.messageText = "Agent Indicator"; alert.informativeText = message
                alert.runModal()
            }
        }.store(in: &subscriptions)
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showSettings(); return false }
    func applicationWillTerminate(_ notification: Notification) { model?.shutdown() }
    private func installMenus() {
        let main = NSMenu(); let appMenu = NSMenu(); let appItem = NSMenuItem(); appItem.submenu = appMenu; main.addItem(appItem)
        let prefs = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","); prefs.target = self; appMenu.addItem(prefs)
        appMenu.addItem(.separator()); appMenu.addItem(withTitle: "Quit Agent Indicator", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let edit = NSMenu(title: "Edit"); let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: ""); editItem.submenu = edit; main.addItem(editItem)
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        NSApp.mainMenu = main
    }
    private func updateIcon() {
        let image = NSImage(systemSymbolName: model.paused ? "pause.circle" : model.status.symbol, accessibilityDescription: model.headline)
        image?.isTemplate = true; item.button?.image = image
        let count = model.monitor.chats.filter { $0.status == .attention }.count
        item.button?.title = count > 0 ? " \(count)" : ""
        item.button?.toolTip = "Agent Indicator — \(model.headline)"
        item.button?.setAccessibilityLabel("Agent Indicator, \(model.headline)")
    }
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === statusMenu else { return }
        menu.removeAllItems()
        let headline = NSMenuItem(title: model.headline, action: nil, keyEquivalent: "")
        menu.addItem(headline)
        let chats = NSMenu(title: "Chats")
        if model.monitor.chats.isEmpty { chats.addItem(withTitle: "No recent chats", action: nil, keyEquivalent: "") }
        for chat in model.monitor.chats {
            let name = chat.title.count > 48 ? String(chat.title.prefix(47)) + "…" : chat.title
            let row = NSMenuItem(title: "\(chat.status.label) · \(name)", action: nil, keyEquivalent: "")
            row.toolTip = chat.title + (chat.project.isEmpty ? "" : " · " + chat.project)
            row.image = NSImage(systemSymbolName: chat.status.symbol, accessibilityDescription: chat.status.label)
            let actions = NSMenu(title: chat.title)
            let open = NSMenuItem(title: "Open Codex", action: #selector(openCodex), keyEquivalent: ""); open.target = self; actions.addItem(open)
            if chat.status == .ready {
                let read = NSMenuItem(title: "Mark read", action: #selector(markRead(_:)), keyEquivalent: "")
                read.target = self; read.representedObject = chat.id; actions.addItem(read)
            }
            row.submenu = actions; chats.addItem(row)
        }
        let chatMenu = NSMenuItem(title: "Chats (\(model.monitor.chats.count))", action: nil, keyEquivalent: "")
        chatMenu.submenu = chats; menu.addItem(chatMenu)
        if !model.light.available { menu.addItem(withTitle: model.light.connection, action: nil, keyEquivalent: "") }
        if model.light.capsLock { menu.addItem(withTitle: "Caps Lock has the light", action: nil, keyEquivalent: "") }
        if let issue = model.monitor.issue {
            let warning = NSMenuItem(title: model.monitor.connection == "Status unavailable" ? "Monitoring unavailable" : "Approval detection limited", action: nil, keyEquivalent: "")
            warning.toolTip = issue; menu.addItem(warning)
        }
        menu.addItem(.separator())
        let open = NSMenuItem(title: "Open Codex", action: #selector(openCodex), keyEquivalent: ""); open.target = self; menu.addItem(open)
        let pause = NSMenuItem(title: model.paused ? "Resume indicators" : "Pause indicators", action: #selector(togglePause), keyEquivalent: ""); pause.target = self; menu.addItem(pause)
        let prefs = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","); prefs.target = self; menu.addItem(prefs)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Agent Indicator", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }
    @objc private func openCodex() { model.openCodex() }
    @objc private func markRead(_ sender: NSMenuItem) {
        if let id = sender.representedObject as? String { model.monitor.markRead(id) }
    }
    @objc private func togglePause() { model.paused.toggle() }
    @objc private func openSettings() { showSettings() }
    private func showSettings() {
        if settings == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 570, height: 490), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "Agent Indicator"; window.isReleasedWhenClosed = false
            window.contentViewController = NSHostingController(rootView: SettingsView(model: model))
            window.center(); settings = window
        }
        NSApp.activate(ignoringOtherApps: true); settings?.makeKeyAndOrderFront(nil)
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        DispatchQueue.main.async { [weak self] in self?.model.openCodex() }; completionHandler()
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) { completionHandler([.banner, .list]) }
}
@main
struct AgentIndicatorMain {
    @MainActor static func main() {
        let app = NSApplication.shared; let delegate = AppDelegate(); app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
