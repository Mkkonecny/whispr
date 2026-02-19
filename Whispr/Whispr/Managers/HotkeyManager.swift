//
//  HotkeyManager.swift
//  Whispr
//

import Carbon
import CoreGraphics
import Foundation

class HotkeyManager {
    private let errorManager: ErrorManager
    var onToggle: (() -> Void)?

    private var eventTap: CFMachPort?

    init(errorManager: ErrorManager) {
        self.errorManager = errorManager
        setupGlobalHotkey()
    }

    deinit {
        if let eventTap = eventTap {
            CFMachPortInvalidate(eventTap)
        }
    }

    func checkAccessibilityPermission() {
        let options: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)

        if accessEnabled {
            print("[HotkeyManager] INFO: Accessibility permission granted")
        } else {
            print("[HotkeyManager] WARN: Accessibility permission required")
            errorManager.handle(error: WhisprError.accessibilityPermissionDenied, level: .modal)
        }
    }

    private func setupGlobalHotkey() {
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)

        guard
            let eventTap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: CGEventMask(eventMask),
                callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                    guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                    let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
                    return manager.handleKeyEvent(proxy: proxy, type: type, event: event)
                },
                userInfo: Unmanaged.passUnretained(self).toOpaque()
            )
        else {
            print("[HotkeyManager] ERROR: Failed to create global event tap")
            return
        }

        self.eventTap = eventTap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    private func handleKeyEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent)
        -> Unmanaged<CGEvent>?
    {
        guard type == .keyDown else { return Unmanaged.passRetained(event) }

        // Ignore key repeats to prevent rapid toggling
        if event.getIntegerValueField(.keyboardEventAutorepeat) != 0 {
            return Unmanaged.passRetained(event)
        }

        let flags = event.flags
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        let isCmd = flags.contains(.maskCommand)
        let isShift = flags.contains(.maskShift)
        let isSpace = (keyCode == 49)

        if isCmd && isShift && isSpace {
            DispatchQueue.main.async { [weak self] in
                print("[HotkeyManager] INFO: Hotkey triggered (Cmd+Shift+Space)")
                self?.onToggle?()
            }
            return nil
        }

        return Unmanaged.passRetained(event)
    }
}
