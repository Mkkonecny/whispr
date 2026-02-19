//
//  ErrorManager.swift
//  Whispr
//

import AppKit
import Foundation
import UserNotifications

class ErrorManager {
    enum NotificationLevel {
        case silent
        case subtle
        case banner
        case modal
    }

    func handle(error: Error, level: NotificationLevel) {
        print("[ErrorManager] ERROR: \(error.localizedDescription)")

        DispatchQueue.main.async {
            switch level {
            case .modal:
                self.showModalAlert(error: error)
            case .banner:
                self.showBannerNotification(error: error)
            default:
                break
            }
        }
    }

    private func showBannerNotification(error: Error) {
        let notification = UNMutableNotificationContent()
        notification.title = "Whispr"
        notification.body = error.localizedDescription
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(
                identifier: UUID().uuidString, content: notification, trigger: nil))
    }

    private func showModalAlert(error: Error) {
        let alert = NSAlert()
        alert.messageText = "Whispr Error"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning

        if let we = error as? WhisprError {
            if we == .microphonePermissionDenied || we == .accessibilityPermissionDenied {
                alert.addButton(withTitle: "Open System Settings")
                alert.addButton(withTitle: "Cancel")
                if alert.runModal() == .alertFirstButtonReturn {
                    self.openSystemPreferences()
                }
                return
            }
        }

        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func openSystemPreferences() {
        let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
        NSWorkspace.shared.open(url)
    }
}
