import Foundation
import Combine
import IOKit.hid
import CoreGraphics

@MainActor
final class KeyboardLight: ObservableObject {
    @Published private(set) var connection = "Checking keyboard…"
    @Published private(set) var capsLock = false
    @Published private(set) var testing: TaskStatus?
    private var manager: IOHIDManager?
    private var device: IOHIDDevice?
    private var element: IOHIDElement?
    private var timer: Timer?
    private var lastValue: Bool?
    private var epoch = Date()
    private var testEnds: Date?
    private var desired: TaskStatus = .idle
    private var paused = false
    var available: Bool { device != nil && element != nil }

    func connect() {
        release()
        if let manager { IOHIDManagerClose(manager, 0) }
        device = nil; element = nil; lastValue = nil
        guard IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted else {
            connection = "Input Monitoring required"; return
        }
        let next = IOHIDManagerCreate(kCFAllocatorDefault, 0)
        manager = next
        IOHIDManagerSetDeviceMatching(next, [kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop, kIOHIDDeviceUsageKey: kHIDUsage_GD_Keyboard] as CFDictionary)
        guard IOHIDManagerOpen(next, 0) == kIOReturnSuccess else {
            connection = "Input Monitoring required"; return
        }
        for candidate in IOHIDManagerCopyDevices(next) as? Set<IOHIDDevice> ?? [] {
            guard (IOHIDDeviceGetProperty(candidate, "Built-In" as CFString) as? NSNumber)?.boolValue == true else { continue }
            let match = [kIOHIDElementUsagePageKey: kHIDPage_LEDs, kIOHIDElementUsageKey: kHIDUsage_LED_CapsLock] as CFDictionary
            for output in IOHIDDeviceCopyMatchingElements(candidate, match, 0) as? [IOHIDElement] ?? [] where IOHIDElementGetType(output) == kIOHIDElementTypeOutput {
                device = candidate; element = output
                connection = "Built-in keyboard connected"
                schedule(); return
            }
        }
        connection = "Built-in LED unavailable"
    }
    func requestAccess() {
        _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") { NSWorkspace.shared.open(url) }
    }
    func set(_ status: TaskStatus, paused: Bool) {
        if desired != status { epoch = Date() }
        desired = status; self.paused = paused
        if paused { testing = nil; testEnds = nil; release() }
        else { schedule() }
    }
    func preview(_ status: TaskStatus) {
        guard available else { return }
        testing = status; testEnds = Date().addingTimeInterval(6); epoch = Date()
        schedule()
    }
    func stopPreview() { testing = nil; testEnds = nil; epoch = Date(); schedule() }
    private func schedule() {
        timer?.invalidate()
        tick()
        guard available, !paused else { return }
        let active = testing != nil || ![TaskStatus.idle, .unavailable, .stopped].contains(desired)
        let next = Timer(timeInterval: active ? 0.05 : 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        next.tolerance = active ? 0.01 : 0.1
        RunLoop.main.add(next, forMode: .common); timer = next
    }
    private func tick() {
        let actual = CGEventSource.flagsState(.combinedSessionState).contains(.maskAlphaShift)
        if capsLock != actual { capsLock = actual }
        if let testEnds, Date() >= testEnds { testing = nil; self.testEnds = nil; epoch = Date(); schedule(); return }
        let state = testing ?? desired
        let t = Date().timeIntervalSince(epoch)
        let on: Bool
        if actual { on = true }
        else if paused { on = false }
        else { on = state.lightIsOn(at: t) }
        guard lastValue != on else { return }
        if !write(on) {
            _ = write(actual)
            device = nil; element = nil; timer?.invalidate(); timer = nil
            connection = "LED write failed · reconnect keyboard"
        }
    }
    @discardableResult private func write(_ on: Bool) -> Bool {
        guard let device, let element else { return false }
        let value = IOHIDValueCreateWithIntegerValue(kCFAllocatorDefault, element, mach_absolute_time(), on ? 1 : 0)
        let result = IOHIDDeviceSetValue(device, element, value)
        if result == kIOReturnSuccess { lastValue = on; return true }
        return false
    }
    func release() {
        timer?.invalidate(); timer = nil; testing = nil; testEnds = nil
        _ = write(CGEventSource.flagsState(.combinedSessionState).contains(.maskAlphaShift))
    }
    func close() {
        release()
        if let manager { IOHIDManagerClose(manager, 0) }
        manager = nil; device = nil; element = nil
    }
}
import AppKit
