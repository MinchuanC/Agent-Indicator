import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        TabView {
            Form {
                Section {
                    Toggle("Launch at login", isOn: Binding(get: { model.loginEnabled }, set: { model.setLogin($0) }))
                    if let message = model.loginMessage { Text(message).font(.caption).foregroundStyle(.orange) }
                    Toggle("Silent notifications", isOn: $model.notifications)
                    if model.notifications {
                        LabeledContent("Notification access", value: model.notificationState)
                        if model.notificationState.contains("Disabled") { Button("Open Notification Settings…") { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!) } }
                    }
                }
                Section {
                    LabeledContent("Version", value: "1.0 · Personal edition")
                    Button("Open Codex") { model.openCodex() }
                    Button("Quit Agent Indicator") { NSApp.terminate(nil) }.foregroundStyle(.secondary)
                }
            }.formStyle(.grouped).tabItem { Label("General", systemImage: "gearshape") }
            Form {
                Section("Caps Lock light") {
                    LabeledContent("Keyboard", value: model.light.connection)
                    if model.light.capsLock { Label("Caps Lock is on. Patterns are suspended.", systemImage: "capslock.fill").foregroundStyle(.secondary) }
                    ForEach([TaskStatus.working, .attention, .ready], id: \.self) { status in
                        HStack {
                            Image(systemName: status.symbol).foregroundStyle(status.tint).frame(width: 22)
                            Text(status.label)
                            Spacer()
                            PatternStrip(status: status).frame(width: 100, height: 18).accessibilityHidden(true)
                            Button(model.light.testing == status ? "Playing…" : "Preview") { model.light.preview(status) }.disabled(!model.light.available || model.paused)
                        }
                    }
                    if model.light.testing != nil { Button("Stop preview") { model.light.stopPreview() } }
                }
                Section {
                    Text("Actual Caps Lock always takes priority. A ready response means a turn ended; it does not certify that the task succeeded.").font(.callout).foregroundStyle(.secondary)
                    Toggle("Pause indicators", isOn: $model.paused)
                }
            }.formStyle(.grouped).tabItem { Label("Signals", systemImage: "waveform.path") }
            Form {
                Section("Connection") {
                    LabeledContent("Codex", value: model.monitor.connection)
                    LabeledContent("Keyboard", value: model.light.connection)
                    if let last = model.monitor.lastEvent { LabeledContent("Last event") { Text(last, style: .relative).foregroundStyle(.secondary) } }
                    Button("Reconnect") { model.reconnect() }
                }
                Section("Keyboard access") {
                    Button("Open Input Monitoring…") { model.light.requestAccess() }
                    Text("Enable Agent Indicator, then quit and reopen it if macOS requests a restart. Input Monitoring is used to access the built-in keyboard LED. Keystrokes are not captured.").font(.callout).foregroundStyle(.secondary)
                }
                Section("Local monitoring") {
                    Text(model.monitor.issue ?? "Reading local Codex desktop events.").font(.callout)
                    Text("No prompts, responses, or credentials are stored or sent. Chat titles and project names are held in memory. No approvals are made on your behalf.").font(.callout).foregroundStyle(.secondary)
                }
            }.formStyle(.grouped).tabItem { Label("Connection", systemImage: "point.3.connected.trianglepath.dotted") }
        }.padding(.top, 12).frame(width: 570, height: 490)
        .onAppear { model.refreshLogin(); model.refreshNotifications() }
    }
}
struct PatternStrip: View {
    let status: TaskStatus
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<24) { i in
                let on = status.lightIsOn(at: (Double(i) + 0.5) * 0.125)
                Capsule().fill(on ? status.tint : Color.secondary.opacity(0.15)).frame(height: on ? 16 : 5)
            }
        }
    }
}
