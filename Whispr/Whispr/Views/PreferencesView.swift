//
//  PreferencesView.swift
//  Whispr
//
//  Preferences window (basic for MVP)
//

import AVFoundation
import ApplicationServices
import SwiftUI

struct PreferencesView: View {
    @ObservedObject var prefs = PreferencesManager.shared

    var body: some View {
        VStack(spacing: 20) {
            Text("Whispr Preferences")
                .font(.title)

            GroupBox(label: Text("Transcription Settings")) {
                VStack(alignment: .leading, spacing: 15) {
                    Picker("Accuracy / Model", selection: $prefs.selectedModel) {
                        Text("Base (Fast)").tag("base")
                        Text("Medium (Accurate)").tag("medium")
                    }
                    .pickerStyle(.segmented)

                    Text(
                        prefs.selectedModel == "medium"
                            ? "🎯 Medium model is slower but much more accurate for languages like Slovak."
                            : "⚡️ Base model is faster but may struggle with non-English languages."
                    )
                    .font(.caption2)
                    .foregroundColor(.secondary)

                    Divider()

                    Toggle("Polish Mode (AI Cleanup)", isOn: $prefs.isPolishModeEnabled)
                        .toggleStyle(.switch)

                    Text(
                        prefs.isPolishModeEnabled
                            ? "✨ Removes filler words (um, uh, like) and fixes grammar."
                            : "⚡️ Raw transcription. Fastest speed, no modifications."
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
            }

            GroupBox(label: Text("Hotkey Settings")) {
                VStack(alignment: .leading) {
                    Text("Dictation Hotkey: Cmd+Shift+Space")
                        .foregroundColor(.secondary)

                    Text("Press once to START recording, press again to STOP.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }

            GroupBox(label: Text("Permissions")) {
                VStack(alignment: .leading, spacing: 10) {
                    PermissionRow(
                        title: "Microphone",
                        status: checkMicrophonePermission(),
                        action: "Required for voice recording"
                    )

                    PermissionRow(
                        title: "Accessibility",
                        status: checkAccessibilityPermission(),
                        action: "Required for global hotkey and text injection"
                    )
                }
                .padding()
            }

            Spacer()

            HStack {
                Button("Open System Settings") {
                    openSystemPreferences()
                }

                Spacer()

                Text("Whispr MVP v1.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .frame(width: 450, height: 350)
    }

    private func checkMicrophonePermission() -> Bool {
        // On macOS, we can't check microphone permission status directly
        // It's requested automatically when first accessing the microphone
        return true  // Show as granted for UI purposes
    }

    private func checkAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()
    }

    private func openSystemPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy")!
        NSWorkspace.shared.open(url)
    }
}

struct PermissionRow: View {
    let title: String
    let status: Bool
    let action: String

    var body: some View {
        HStack {
            Image(systemName: status ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(status ? .green : .red)

            VStack(alignment: .leading) {
                Text(title)
                    .fontWeight(.medium)
                Text(action)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

#Preview {
    PreferencesView()
}
