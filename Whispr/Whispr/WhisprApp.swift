//
//  WhisprApp.swift
//  Whispr
//
//  Created by Mkkonecny on 2026-02-14.
//

import AppKit
import SwiftUI

@main
struct WhisprApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            PreferencesView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?

    // Managers
    var audioManager: AudioCaptureManager?
    var transcriptionManager: TranscriptionManager?
    var cleanupManager: CleanupManager?
    var textInjectionManager: TextInjectionManager?
    var hotkeyManager: HotkeyManager?
    var errorManager: ErrorManager?
    private var preferencesWindow: NSWindow?
    private var recordingWindow: RecordingWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Carry out critical non-UI tasks immediately
        AudioCaptureManager.clearTempDirectory()

        // Defer UI setup slightly to avoid layout recursion warnings
        // caused by AppKit/SwiftUI lifecycle overlap
        DispatchQueue.main.async { [weak self] in
            // Configure as menu bar app (no Dock icon)
            NSApp.setActivationPolicy(.accessory)

            // Setup Menu
            self?.setupStatusBarMenu()

            // Initialize managers
            self?.setupManagers()

            // Wait another short moment before potentially popping up permission dialogs
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.checkRequiredPermissions()
            }
        }
    }

    private func setupStatusBarMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Whispr")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Whispr is Ready", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            NSMenuItem(
                title: "Preferences...", action: #selector(showPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            NSMenuItem(
                title: "Quit Whispr", action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    private func setupManagers() {
        errorManager = ErrorManager()

        audioManager = AudioCaptureManager(errorManager: errorManager!)
        transcriptionManager = TranscriptionManager(errorManager: errorManager!)
        cleanupManager = CleanupManager(errorManager: errorManager!)
        textInjectionManager = TextInjectionManager(errorManager: errorManager!)
        hotkeyManager = HotkeyManager(errorManager: errorManager!)

        // Pre-initialize floating recording window (fixes first-run appearance issue)
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let audioManager = self.audioManager else { return }
            let barView = RecordingBarView(audioManager: audioManager)
            self.recordingWindow = RecordingWindow(contentView: AnyView(barView))
        }

        // Wire up the pipeline
        hotkeyManager?.onRecordingStart = { [weak self] in
            guard let self = self else { return }

            // Show floating recording bar and hide system menu bar icon
            DispatchQueue.main.async {
                self.recordingWindow?.show()
                self.statusItem?.isVisible = false

                // Extra beat to ensure window is front before starting animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("StartRecordingAnimation"), object: nil)
                }
            }

            self.audioManager?.startRecording()
        }

        hotkeyManager?.onRecordingStop = { [weak self] in
            guard let self = self else { return }

            // 1. Notify the view to shrink back to logo, then to 0 (after 1s persistence)
            NotificationCenter.default.post(
                name: NSNotification.Name("StopRecordingAnimation"), object: nil)

            // 2. Wait for full sequence: shrink(0.5s) + logo persistence(1.0s) + fade(0.5s) + buffer
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                self.recordingWindow?.hide()
                self.statusItem?.isVisible = true
                self.updateMenuBarIcon(state: .processing)
            }

            self.audioManager?.stopRecording { audioPath in
                self.processRecording(audioPath: audioPath)
            }
        }
    }

    private func processRecording(audioPath: String?) {
        guard let audioPath = audioPath else {
            updateMenuBarIcon(state: .ready)
            return
        }

        transcriptionManager?.transcribe(audioPath: audioPath) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let transcription):
                    // Run AI cleanup (Polish) if enabled
                    self?.cleanupManager?.cleanup(text: transcription.text) { cleanupResult in
                        DispatchQueue.main.async {
                            let finalText = (try? cleanupResult.get()) ?? transcription.text
                            self?.textInjectionManager?.inject(text: finalText) { success in
                                self?.updateMenuBarIcon(state: success ? .ready : .error)
                            }
                        }
                    }
                case .failure(let error):
                    self?.errorManager?.handle(error: error, level: .banner)
                    self?.updateMenuBarIcon(state: .error)
                }
                self?.transcriptionManager?.cleanup(audioPath: audioPath)
            }
        }
    }

    private func checkRequiredPermissions() {
        audioManager?.checkMicrophonePermission()
        hotkeyManager?.checkAccessibilityPermission()
    }

    private func updateMenuBarIcon(state: AppState) {
        DispatchQueue.main.async { [weak self] in
            guard let button = self?.statusItem?.button else { return }

            switch state {
            case .ready:
                button.image = NSImage(
                    systemSymbolName: "mic.fill", accessibilityDescription: "Ready")
            case .recording:
                button.image = NSImage(
                    systemSymbolName: "mic.circle.fill", accessibilityDescription: "Recording")
            case .processing:
                button.image = NSImage(
                    systemSymbolName: "waveform.circle", accessibilityDescription: "Processing")
            case .error:
                button.image = NSImage(
                    systemSymbolName: "exclamationmark.triangle.fill",
                    accessibilityDescription: "Error")
            }
        }
    }

    @objc func showPreferences() {
        if preferencesWindow == nil {
            let contentView = PreferencesView()
                .frame(minWidth: 450, minHeight: 450)

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 450, height: 450),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered, defer: false)
            window.center()
            window.title = "Whispr Preferences"
            window.contentView = NSHostingView(rootView: contentView)
            window.isReleasedWhenClosed = false
            window.level = .floating  // Keep on top during setup
            preferencesWindow = window
        }

        NSApp.activate(ignoringOtherApps: true)
        preferencesWindow?.makeKeyAndOrderFront(nil)
        preferencesWindow?.orderFrontRegardless()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Clean up status item to prevent ghost icons (though macOS usually handles this)
        statusItem = nil
    }
}

// App metadata
enum AppState {
    case ready
    case recording
    case processing
    case error
}
