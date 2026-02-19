//
//  PreferencesView.swift
//  Whispr
//
//  Redesigned using native macOS 26 Liquid Glass APIs:
//  • GlassEffectContainer — groups glass shapes so they blend & morph
//  • .glassEffect()       — applies the Liquid Glass material to any view
//  • .glassEffectID()     — ties paired views together for morph transitions
//
//  Minimum deployment target: macOS 26.2 (see project.pbxproj)
//

import AVFoundation
import ApplicationServices
import AppKit
import SwiftUI

// MARK: - Main View

@available(macOS 26.0, *)
struct PreferencesView: View {
    @ObservedObject var prefs = PreferencesManager.shared
    @State private var selectedTab: PrefsTab = .transcription
    @Namespace private var glassNamespace

    var body: some View {
        VStack(spacing: 0) {

            // ── Header ───────────────────────────────────────────────────
            PrefsHeader(
                selectedTab: $selectedTab,
                glassNamespace: glassNamespace
            )

            // ── Scrollable body ──────────────────────────────────────────
            ScrollView(.vertical, showsIndicators: false) {
                Group {
                    switch selectedTab {
                    case .transcription:
                        TranscriptionTab(prefs: prefs, glassNamespace: glassNamespace)
                    case .hotkeys:
                        HotkeysTab()
                    case .permissions:
                        PermissionsTab(glassNamespace: glassNamespace)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .frame(maxHeight: .infinity)

            // ── Footer ───────────────────────────────────────────────────
            PrefsFooter()
        }
        .frame(width: 520, height: 560)
    }
}

// MARK: - Tab Enum

enum PrefsTab: String, CaseIterable {
    case transcription = "Transcription"
    case hotkeys = "Hotkeys"
    case permissions = "Permissions"

    var icon: String {
        switch self {
        case .transcription: return "waveform"
        case .hotkeys: return "keyboard"
        case .permissions: return "lock.shield"
        }
    }
}

// MARK: - Header

@available(macOS 26.0, *)
struct PrefsHeader: View {
    @Binding var selectedTab: PrefsTab
    var glassNamespace: Namespace.ID

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // App identity row
            HStack(spacing: 12) {
                ZStack {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 36, height: 36)
                .glassEffect(
                    .thin.tint(.purple),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Whispr Preferences")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Manage your transcription settings")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 14)

            // Tab bar — all tabs share one GlassEffectContainer so their
            // glass shapes can blend and morph into each other
            GlassEffectContainer(spacing: 6) {
                HStack(spacing: 4) {
                    ForEach(PrefsTab.allCases, id: \.self) { tab in
                        let isSelected = selectedTab == tab
                        Button {
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                                selectedTab = tab
                            }
                        } label: {
                            Label(tab.rawValue, systemImage: tab.icon)
                                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                        }
                        .buttonStyle(.plain)
                        // Selected tab gets full glass — unselected get clear overlay;
                        // the same glassEffectID key causes SwiftUI to morph between them
                        .glassEffect(isSelected ? .regular : .clearOverlay, in: Capsule())
                        .glassEffectID(
                            isSelected ? "pref-selected-tab" : "pref-tab-\(tab.rawValue)",
                            in: glassNamespace
                        )
                        .opacity(isSelected ? 1.0 : 0.6)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            Divider()
        }
    }
}

// MARK: - Footer

@available(macOS 26.0, *)
struct PrefsFooter: View {
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Button("Open System Settings") {
                    NSWorkspace.shared.open(
                        URL(
                            string:
                                "x-apple.systempreferences:com.apple.preference.security?Privacy")!
                    )
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .glassEffect(.thin, in: Capsule())

                Spacer()

                HStack(spacing: 5) {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                    Text("Whispr v1.0")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Section Container

/// Groups rows into a titled section. Rows are wrapped in a single
/// GlassEffectContainer so adjacent glass elements can blend when revealed.
@available(macOS 26.0, *)
struct PrefSection<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var rows: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section header
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            // Wrap all rows in one GlassEffectContainer so dynamically
            // revealed rows morph smoothly into the group's glass background
            GlassEffectContainer(spacing: 0) {
                VStack(spacing: 0) {
                    rows
                }
                .glassEffect(
                    .regular,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
            }
        }
    }
}

// MARK: - Row Building Block

/// A standard preference row: icon badge + title/subtitle + trailing widget
@available(macOS 26.0, *)
struct PrefRow<Trailing: View>: View {
    let icon: String
    var iconColors: [Color]
    let title: String
    let subtitle: String
    var badge: (text: String, color: Color)? = nil
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 14) {
            // Colored icon badge: gradient fill + glass overlay for depth
            ZStack {
                LinearGradient(
                    colors: iconColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
            }
            .frame(width: 36, height: 36)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .glassEffect(.clearOverlay, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            // Text labels
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                    if let badge = badge {
                        GlassBadge(text: badge.text, tint: badge.color)
                    }
                }
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 6)

            trailing
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}

// MARK: - Glass Badge

/// A tiny pill badge that uses glassEffect for its background
@available(macOS 26.0, *)
struct GlassBadge: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .glassEffect(.thin.tint(tint.opacity(0.35)), in: Capsule())
    }
}

// MARK: - Divider

struct PrefDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 64)  // indent past icon (14 pad + 36 icon + 14 gap)
    }
}

// MARK: - Transcription Tab

@available(macOS 26.0, *)
struct TranscriptionTab: View {
    @ObservedObject var prefs: PreferencesManager
    var glassNamespace: Namespace.ID

    var body: some View {
        VStack(spacing: 20) {

            // ── Model selector ───────────────────────────────────────────
            PrefSection(
                title: "Model Selection",
                subtitle: "Choose the Whisper model for speech recognition."
            ) {
                PrefRow(
                    icon: "cpu.fill",
                    iconColors: [.purple, .indigo],
                    title: "Accuracy / Speed",
                    subtitle: prefs.selectedModel == "medium"
                        ? "Medium model — highly accurate, great for Slovak and non-English."
                        : "Base model — fastest, optimal for English dictation."
                ) {
                    // Liquid Glass segmented control using GlassEffectContainer
                    // so segments morph into each other on selection
                    GlassEffectContainer(spacing: 4) {
                        HStack(spacing: 2) {
                            ForEach(
                                [("base", "⚡ Base"), ("medium", "🎯 Medium")],
                                id: \.0
                            ) { value, label in
                                let isSelected = prefs.selectedModel == value
                                Button(label) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
                                        prefs.selectedModel = value
                                    }
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .glassEffect(isSelected ? .regular : .clearOverlay, in: Capsule())
                                .glassEffectID(
                                    isSelected ? "modelSel" : "modelSel-\(value)",
                                    in: glassNamespace
                                )
                                .opacity(isSelected ? 1.0 : 0.55)
                            }
                        }
                    }
                }

                // Conditional processing-time hint
                if prefs.selectedModel == "medium" {
                    PrefDivider()
                    PrefRow(
                        icon: "clock.fill",
                        iconColors: [.orange, .red],
                        title: "Processing takes a few extra seconds",
                        subtitle: "Expect ~2–5 seconds per transcription on Apple Silicon."
                    ) {
                        Text("~2–5s")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .glassEffect(.thin, in: Capsule())
                    }
                    .transition(.push(from: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: prefs.selectedModel)

            // ── Polish mode ──────────────────────────────────────────────
            PrefSection(
                title: "AI Cleanup",
                subtitle: "Automatically polish your transcription before inserting it."
            ) {
                PrefRow(
                    icon: "sparkles",
                    iconColors: [.pink, .purple],
                    title: "Polish Mode",
                    subtitle: "Removes filler words (um, uh, like) and fixes grammar.",
                    badge: prefs.isPolishModeEnabled ? (text: "Active", color: .green) : nil
                ) {
                    Toggle("", isOn: $prefs.isPolishModeEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                // Conditional agent info row
                if prefs.isPolishModeEnabled {
                    PrefDivider()
                    PrefRow(
                        icon: "text.bubble.fill",
                        iconColors: [.teal, .mint],
                        title: "Hey Whispr Agent",
                        subtitle:
                            "Say \"Hey Whispr\" before a command to run the AI on selected text.",
                        badge: (text: "Live", color: .blue)
                    ) {
                        EmptyView()
                    }
                    .transition(.push(from: .top).combined(with: .opacity))
                }
            }
            .animation(
                .spring(response: 0.4, dampingFraction: 0.8), value: prefs.isPolishModeEnabled)
        }
    }
}

// MARK: - Hotkeys Tab

@available(macOS 26.0, *)
struct HotkeysTab: View {
    var body: some View {
        VStack(spacing: 20) {

            PrefSection(
                title: "Dictation Hotkey",
                subtitle: "Press once to start recording, again to stop and transcribe."
            ) {
                PrefRow(
                    icon: "command",
                    iconColors: [Color(.sRGB, red: 0.38, green: 0.38, blue: 0.42), .gray],
                    title: "Start / Stop Recording",
                    subtitle: "Global hotkey — works across all apps."
                ) {
                    Text("⌘ ⇧ Space")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .glassEffect(
                            .thin, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }

            PrefSection(
                title: "AI Agent Mode",
                subtitle: "Use your voice to issue commands to the AI assistant."
            ) {
                PrefRow(
                    icon: "mic.badge.plus",
                    iconColors: [.blue, .cyan],
                    title: "Invoke with \"Hey Whispr\"",
                    subtitle: "Begin recording with \"Hey Whispr\" to activate agent mode.",
                    badge: (text: "Live", color: .blue)
                ) {
                    EmptyView()
                }

                PrefDivider()

                PrefRow(
                    icon: "text.cursor",
                    iconColors: [.indigo, .purple],
                    title: "Context from selected text",
                    subtitle: "Whispr reads your current text selection and passes it to the LLM."
                ) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.system(size: 17))
                }
            }
        }
    }
}

// MARK: - Permissions Tab

@available(macOS 26.0, *)
struct PermissionsTab: View {
    var glassNamespace: Namespace.ID

    @State private var micGranted: Bool = false
    @State private var accessGranted: Bool = false

    var body: some View {
        PrefSection(
            title: "Permissions",
            subtitle: "Whispr requires these permissions to function correctly."
        ) {
            // Microphone
            PrefRow(
                icon: "mic.fill",
                iconColors: [.green, .teal],
                title: "Microphone",
                subtitle: "Required to capture your voice during recording sessions.",
                badge: micGranted
                    ? (text: "Granted", color: .green)
                    : (text: "Required", color: .orange)
            ) {
                if micGranted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.system(size: 18))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .glassEffect(.thin, in: Capsule())
                        .glassEffectID("micAction", in: glassNamespace)
                } else {
                    Button("Allow") {
                        AVCaptureDevice.requestAccess(for: .audio) { granted in
                            DispatchQueue.main.async {
                                withAnimation { micGranted = granted }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .glassEffect(.thin, in: Capsule())
                    .glassEffectID("micAction", in: glassNamespace)
                }
            }

            PrefDivider()

            // Accessibility
            PrefRow(
                icon: "accessibility",
                iconColors: [.blue, .indigo],
                title: "Accessibility",
                subtitle: "Required for global hotkeys and injecting text into any app.",
                badge: accessGranted
                    ? (text: "Granted", color: .green)
                    : (text: "Required", color: .orange)
            ) {
                if accessGranted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.system(size: 18))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .glassEffect(.thin, in: Capsule())
                        .glassEffectID("axAction", in: glassNamespace)
                } else {
                    Button("Set up") {
                        NSWorkspace.shared.open(
                            URL(
                                string:
                                    "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                            )!
                        )
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .glassEffect(.thin, in: Capsule())
                    .glassEffectID("axAction", in: glassNamespace)
                }
            }
        }
        .onAppear {
            micGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
            accessGranted = AXIsProcessTrusted()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            micGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
            accessGranted = AXIsProcessTrusted()
        }
    }
}

// MARK: - Preview

#Preview {
    if #available(macOS 26.0, *) {
        PreferencesView()
    }
}
