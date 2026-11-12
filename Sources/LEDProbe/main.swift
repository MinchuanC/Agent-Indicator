import Foundation
import IOKit.hid
import CoreGraphics

// This probe never synthesizes keys, seizes a keyboard, or reads keystrokes.
func capsLockOn() -> Bool {
    CGEventSource.flagsState(.combinedSessionState).contains(.maskAlphaShift)
}
func run() -> Int32 {
    let blink = CommandLine.arguments.contains("--blink")
    if CommandLine.arguments.contains("--request-access") {
        print("Access request accepted: \(IOHIDRequestAccess(kIOHIDRequestTypeListenEvent))")
    }
    print("Input Monitoring access: \(IOHIDCheckAccess(kIOHIDRequestTypeListenEvent).rawValue)")
    let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    IOHIDManagerSetDeviceMatching(manager, [kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop, kIOHIDDeviceUsageKey: kHIDUsage_GD_Keyboard] as CFDictionary)
    let opened = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    defer { IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone)) }
    print("Manager open: \(opened)")
    guard opened == kIOReturnSuccess else {
        print("BLOCKED: HID access unavailable. macOS error: \(opened). No LED writes attempted."); return 2
    }
    guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
        print("BLOCKED: no accessible keyboard devices."); return 2
    }
    var found = false
    for device in devices {
        guard (IOHIDDeviceGetProperty(device, "Built-In" as CFString) as? NSNumber)?.boolValue == true else { continue }
        let name = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? "Built-in keyboard"
        let match = [kIOHIDElementUsagePageKey: kHIDPage_LEDs, kIOHIDElementUsageKey: kHIDUsage_LED_CapsLock] as CFDictionary
        guard let elements = IOHIDDeviceCopyMatchingElements(device, match, IOOptionBits(kIOHIDOptionsTypeNone)) as? [IOHIDElement] else { continue }
        for element in elements where IOHIDElementGetType(element) == kIOHIDElementTypeOutput {
            found = true
            print("Found: \(name), Caps Lock output element")
            guard blink else { continue }
            func write(_ on: Bool) -> IOReturn {
                let value = IOHIDValueCreateWithIntegerValue(kCFAllocatorDefault, element, mach_absolute_time(), on ? 1 : 0)
                return IOHIDDeviceSetValue(device, element, value)
            }
            defer { print("Restore result: \(write(capsLockOn()))") }
            guard !capsLockOn() else {
                print("BLOCKED: Caps Lock is enabled; normal indication takes priority."); return 2
            }
            for _ in 0..<2 {
                guard !capsLockOn() else { print("Caps Lock enabled; stopping probe."); return 2 }
                let result = write(true)
                print("LED on result: \(result)")
                guard result == kIOReturnSuccess else { print("BLOCKED: independent LED write failed."); return 2 }
                Thread.sleep(forTimeInterval: 0.35)
                let restored = write(capsLockOn())
                guard restored == kIOReturnSuccess else { print("BLOCKED: LED restoration failed: \(restored)"); return 2 }
                Thread.sleep(forTimeInterval: 0.65)
            }
            print("API write sequence passed. Physical light and typing still require human confirmation.")
        }
    }
    if !found { print("BLOCKED: no accessible built-in Caps Lock LED output element."); return 2 }
    return 0
}
exit(run())
