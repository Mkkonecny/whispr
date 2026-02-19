//
//  TextInjectionManager.swift
//  Whispr
//

import AppKit
import Foundation

class TextInjectionManager {
    private let errorManager: ErrorManager

    init(errorManager: ErrorManager) {
        self.errorManager = errorManager
    }

    func inject(text: String, completion: @escaping (Bool) -> Void) {
        let pasteboard = NSPasteboard.general
        let originalContent = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        simulatePaste()

        // Restore original content after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion(true)
            // Optional: Restore clipboard if desired, but for injection we usually leave it
            // so the user can paste it again if they want.
            if originalContent != nil {
                // pasteboard.clearContents()
                // pasteboard.setString(original, forType: .string)
            }
        }
    }

    func getSelectedText(completion: @escaping (String?) -> Void) {
        let pasteboard = NSPasteboard.general
        let previousContent = pasteboard.string(forType: .string)
        // let previousType = pasteboard.types?.first

        // Clear pasteboard to detect if copy worked
        pasteboard.clearContents()

        // Simulate Cmd+C
        simulateCopy()

        // Wait for system to process copy
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let selectedText = pasteboard.string(forType: .string)

            // Restore previous content
            if let previous = previousContent {
                pasteboard.clearContents()
                pasteboard.setString(previous, forType: .string)
            }

            completion(selectedText)
        }
    }

    private func simulateCopy() {
        let source = CGEventSource(stateID: .combinedSessionState)

        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true)
        cmdDown?.flags = .maskCommand

        let cDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)
        cDown?.flags = .maskCommand

        let cUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        cUp?.flags = .maskCommand

        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)

        cmdDown?.post(tap: .cghidEventTap)
        cDown?.post(tap: .cghidEventTap)
        cUp?.post(tap: .cghidEventTap)
        cmdUp?.post(tap: .cghidEventTap)
    }

    private func simulatePaste() {
        let source = CGEventSource(stateID: .combinedSessionState)

        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true)
        cmdDown?.flags = .maskCommand

        let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        vDown?.flags = .maskCommand

        let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        vUp?.flags = .maskCommand

        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)

        cmdDown?.post(tap: .cghidEventTap)
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
        cmdUp?.post(tap: .cghidEventTap)
    }
}
