import AppKit
import SwiftUI
import Combine
import ServiceManagement
import UserNotifications

extension TaskStatus {
    var tint: Color {
        switch self {
        case .working: return .green
        case .attention: return .orange
        case .ready: return .blue
        case .unavailable: return .orange
        default: return .secondary
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    let monitor = Monitor()
    let light = KeyboardLight()
    @Published var paused = false { didSet { synchronize() } }
    @Published var notifications = UserDefaults.standard.bool(forKey: "notifications") {
        didSet { UserDefaults.standard.set(notifications, forKey: "notifications"); if notifications { requestNotifications() } }
    }
    @Published var notificationState = "Off"
    @Published var loginEnabled = false
    @Published var loginMessage: String?
    @Published var actionError: String?
    private var subscriptions = Set<AnyCancellable>()
    private var delivered = Set<String>()
    private var observers: [NSObjectProtocol] = []
    private var sleeping = false
    var status: TaskStatus {
        if NSRunningApplication.runningApplications(withBundleIdentifier: "com.openai.codex").isEmpty { return .unavailable }
        if ["Disconnected", "Status unavailable", "Connecting"].contains(monitor.connection) { return .unavailable }
        return monitor.chats.map(\.status).max(by: { $0.priority < $1.priority }) ?? .idle
    }
    var headline: String { paused ? "Indicators paused" : status.label }
    init() {
        monitor.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async { self?.objectWillChange.send(); self?.synchronize() }
        }.store(in: &subscriptions)
        light.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &subscriptions)
        monitor.onAttention = { [weak self] chat, key in self?.notify(chat, key: key) }
        let nc = NSWorkspace.shared.notificationCenter
        observers.append(nc.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.sleeping = true; self?.light.close(); self?.monitor.stop() }
        })
        observers.append(nc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.sleeping = false; self?.light.connect(); self?.monitor.start(); self?.synchronize() }
        })
        observers.append(nc.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.sleeping = true; self?.light.release() }
        })
        observers.append(nc.addObserver(forName: NSWorkspace.sessionDidBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.sleeping = false; self?.light.connect(); self?.synchronize() }
        })
    }
    func start() { light.connect(); monitor.start(); refreshLogin(); refreshNotifications(); synchronize() }
    func synchronize() { if !sleeping { light.set(status, paused: paused) } }
    func reconnect() { light.connect(); monitor.refresh(); synchronize() }
    func shutdown() { monitor.stop(); light.close(); observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) } }
    func openCodex() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.openai.codex") else {
            actionError = "Codex could not be found in Applications."; return
        }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            if let error { DispatchQueue.main.async { self.actionError = error.localizedDescription } }
        }
    }
    func refreshLogin() { loginEnabled = SMAppService.mainApp.status == .enabled }
    func setLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginMessage = SMAppService.mainApp.status == .requiresApproval ? "Allow Agent Indicator in System Settings → Login Items." : nil
        } catch { loginMessage = error.localizedDescription }
        refreshLogin()
    }
    func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, error in
            DispatchQueue.main.async { if let error { self.notificationState = error.localizedDescription } else { self.refreshNotifications() } }
        }
    }
    func refreshNotifications() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized, .provisional: self.notificationState = "Allowed · silent"
                case .denied: self.notificationState = "Disabled in System Settings"
                default: self.notificationState = "Not requested"
                }
            }
        }
    }
    private func notify(_ chat: ChatState, key: String) {
        guard notifications, !paused, delivered.insert(chat.id + ":" + key).inserted else { return }
        if delivered.count > 2000 { delivered = [key] }
        let content = UNMutableNotificationContent()
        content.title = chat.status.label
        content.body = chat.title
        content.threadIdentifier = chat.id
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: key, content: content, trigger: nil)) { error in
            if let error { DispatchQueue.main.async { self.notificationState = error.localizedDescription } }
        }
    }
}
