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
            if #available(macOS 26.0, *) {
                PreferencesView()
            } else {
                Text("Whispr requires macOS 26.0 or later.")
                    .padding()
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    private var isStopping = false
    private var hideWindowWorkItem: DispatchWorkItem?

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

    private var recordingGeneration = 0

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
        // Wire up the pipeline
        hotkeyManager?.onToggle = { [weak self] in
            guard let self = self else { return }

            // Prevent accidental restarts while the UI is transitioning out
            if self.isStopping { return }

            if self.audioManager?.isRecording == true {
                self.stopRecording()
            } else {
                self.startRecording()
            }
        }
    }

    private func startRecording() {
        // Cancel any pending hide-window work from a previous stop
        hideWindowWorkItem?.cancel()
        hideWindowWorkItem = nil

        // Increment generation to invalidate any remaining pending operations
        self.recordingGeneration += 1

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
        self.updateMenuBarIcon(state: .recording)
    }

    private func stopRecording() {
        if isStopping { return }
        isStopping = true

        let currentGen = self.recordingGeneration

        // 1. Notify the view to shrink back to logo, then fade out
        NotificationCenter.default.post(
            name: NSNotification.Name("StopRecordingAnimation"), object: nil)

        // 2. Release the stop guard quickly — just enough to debounce a double-tap.
        //    The view's own cancellable work items handle the animation correctly.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isStopping = false
        }

        // 3. Hide window after full animation: shrink(0.5s) + logo(1.0s) + fade(0.5s) + buffer
        let hideWork = DispatchWorkItem { [weak self] in
            guard let self = self, self.recordingGeneration == currentGen else { return }
            self.recordingWindow?.hide()
            self.statusItem?.isVisible = true
            self.updateMenuBarIcon(state: .processing)
        }
        hideWindowWorkItem = hideWork
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2, execute: hideWork)

        // 4. Stop audio and begin processing pipeline
        self.audioManager?.stopRecording { audioPath in
            self.processRecording(audioPath: audioPath)
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
                    let text = transcription.text
                    let isAgentMode =
                        text.lowercased().starts(with: "hey whispr")
                        || text.lowercased().starts(with: "hey whisper")

                    if isAgentMode {
                        // AGENT MODE: Get context from screen + Process command
                        self?.updateMenuBarIcon(state: .processing)  // Keep processing state

                        self?.textInjectionManager?.getSelectedText { selectedText in
                            self?.cleanupManager?.processAgentRequest(
                                command: text, context: selectedText
                            ) { result in
                                DispatchQueue.main.async {
                                    let finalText = (try? result.get()) ?? text
                                    // Inject the result (replacing the selected text we just read)
                                    self?.textInjectionManager?.inject(text: finalText) { success in
                                        self?.updateMenuBarIcon(state: success ? .ready : .error)
                                    }
                                }
                            }
                        }
                    } else {
                        // STANDARD MODE: Cleanup (if enabled) + Inject
                        self?.cleanupManager?.cleanup(text: text) { cleanupResult in
                            DispatchQueue.main.async {
                                let finalText = (try? cleanupResult.get()) ?? text
                                self?.textInjectionManager?.inject(text: finalText) { success in
                                    self?.updateMenuBarIcon(state: success ? .ready : .error)
                                }
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
        guard #available(macOS 26.0, *) else { return }
        if preferencesWindow == nil {
            let contentView = PreferencesView()
                .frame(minWidth: 520, minHeight: 560)

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 560),
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
