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
            if let original = originalContent {
                pasteboard.clearContents()
                pasteboard.setString(original, forType: .string)
            }
            completion(true)
        }
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
