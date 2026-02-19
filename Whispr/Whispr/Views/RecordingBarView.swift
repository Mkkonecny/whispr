import SwiftUI

struct RecordingBarView: View {
    @ObservedObject var audioManager: AudioCaptureManager
    @StateObject private var prefs = PreferencesManager.shared
    @Environment(\.colorScheme) private var colorScheme

    @State private var isShowingLogo = false
    @State private var isExpanded = false
    @State private var isVanishing = false

    // Cancellable work items for the stop animation sequence
    @State private var stopLogoWorkItem: DispatchWorkItem?
    @State private var stopVanishWorkItem: DispatchWorkItem?

    private var normalizedLevel: CGFloat {
        let level = CGFloat(audioManager.audioLevel)
        return min(max(level * 60, 0.05), 1.0)
    }

    private let expansionThreshold: Float = 0.015

    var body: some View {
        let isDark = (colorScheme == .dark)
        let isTintedStyle = (prefs.glassStyle == "tinted")
        let tintOpacity: CGFloat = isTintedStyle ? (isDark ? 0.20 : 0.16) : 0.0
        let backgroundColor: Color = isDark ? .black : .white
        let foregroundColor: Color = isDark ? .white : .black
        let strokeColor: Color = isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.12)

        let baseWidth: CGFloat = isExpanded ? 160 : (isShowingLogo || isVanishing ? 44 : 0)
        let baseHeight: CGFloat = 44
        let ringThickness: CGFloat = 1  // outer ring thickness
        let glassWidth: CGFloat = max(baseWidth - ringThickness * 2, 0)
        let glassHeight: CGFloat = max(baseHeight - ringThickness * 2, 0)
        let glassStrength: Double = 0.95  // Lower values reduce the perceived blur/strength

        ZStack {
            // Solid background base ring (leave center transparent for glass sampling)
            Capsule()
                .strokeBorder(backgroundColor, lineWidth: ringThickness)
                .frame(width: baseWidth, height: baseHeight)
                .allowsHitTesting(false)
                // Base highlight gradient ring
                .overlay(
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: isDark
                                    ? [
                                        Color.white.opacity(0.10), Color.white.opacity(0.02),
                                        Color.clear,
                                    ]
                                    : [
                                        Color.black.opacity(0.12), Color.black.opacity(0.04),
                                        Color.clear,
                                    ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: ringThickness
                        )
                        .blendMode(isDark ? .screen : .multiply)
                        .allowsHitTesting(false)
                )
                // Outer edge stroke
                .overlay(
                    Capsule().strokeBorder(strokeColor, lineWidth: 1)
                )

            Group {
                let content = AnyView(
                    HStack(spacing: 12) {
                        LogoView(foregroundColor: foregroundColor)
                            .frame(width: 19)
                            .opacity(isShowingLogo ? 1 : 0)

                        if isExpanded {
                            HStack(spacing: 3) {
                                ForEach(0..<7) { i in
                                    VisualizerBar(
                                        level: normalizedLevel, index: i,
                                        foregroundColor: foregroundColor)
                                }
                            }
                            .transition(
                                .scale(scale: 0.5, anchor: .leading).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, isExpanded ? 16 : 0)
                )

                #if os(macOS)
                    if #available(macOS 15.0, *) {
                        content
                            .frame(width: glassWidth, height: glassHeight)
                            // Tint overlay directly behind content (morphs with style)
                            .background(
                                Capsule().fill(Color.accentColor.opacity(tintOpacity))
                            )
                            // Live blur material behind tint
                            .background(
                                Capsule().fill(.ultraThinMaterial).opacity(glassStrength)
                            )
                            .overlay(
                                Capsule().strokeBorder(
                                    (isDark
                                        ? Color.white.opacity(0.22) : Color.black.opacity(0.18)),
                                    lineWidth: 0.9
                                )
                                .blendMode(isDark ? .screen : .multiply)
                            )
                            .animation(
                                .spring(response: 0.45, dampingFraction: 0.85), value: isTintedStyle
                            )
                    } else {
                        content
                            .frame(width: baseWidth, height: baseHeight)
                    }
                #else
                    content
                        .frame(width: baseWidth, height: baseHeight)
                #endif
            }
        }
        .foregroundStyle(foregroundColor)
        .opacity(isShowingLogo ? 1 : 0)
        .scaleEffect(isShowingLogo ? 1.0 : 0.8)
        /*
        Removed glass effect overlay here as glass effect is moved behind foreground:
        .overlay(
            Capsule()
                .fill(Color.clear)
                .glassEffect(.regular.tint(Color.white.opacity(0.18)).interactive())
        )
        */
        .onChange(of: audioManager.audioLevel) { old, newValue in
            if isShowingLogo && !isExpanded && newValue > expansionThreshold {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)) {
                    isExpanded = true
                }
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSNotification.Name("StartRecordingAnimation"))
        ) { _ in
            startAnimationSequence()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: NSNotification.Name("StopRecordingAnimation"))
        ) { _ in
            stopAnimationSequence()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    func startAnimationSequence() {
        // Cancel any pending stop-animation work before starting fresh
        stopLogoWorkItem?.cancel()
        stopVanishWorkItem?.cancel()
        stopLogoWorkItem = nil
        stopVanishWorkItem = nil

        isVanishing = false
        isExpanded = false

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
            isShowingLogo = true
        }
    }

    func stopAnimationSequence() {
        // Cancel any previously scheduled stop work (safety guard for rapid toggling)
        stopLogoWorkItem?.cancel()
        stopVanishWorkItem?.cancel()

        // 1. Shrink full capsule back down to logo center
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85, blendDuration: 0)) {
            isExpanded = false
        }

        // 2. Persist Logo for 1.0 seconds, then fade out
        let logoWork = DispatchWorkItem {
            isVanishing = true  // Lock frame width so it doesn't jump to 0
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
                isShowingLogo = false
            }

            // 3. Cleanup vanishing state after animation completes
            let vanishWork = DispatchWorkItem {
                isVanishing = false
            }
            self.stopVanishWorkItem = vanishWork
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: vanishWork)
        }
        self.stopLogoWorkItem = logoWork
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: logoWork)
    }
}

struct LogoView: View {
    var foregroundColor: Color

    var body: some View {
        HStack(alignment: .bottom, spacing: 1.5) {
            RoundedRectangle(cornerRadius: 10)
                .fill(foregroundColor)
                .frame(width: 5, height: 18)
                .rotationEffect(.degrees(-5), anchor: .bottomTrailing)

            RoundedRectangle(cornerRadius: 10)
                .fill(foregroundColor)
                .frame(width: 5, height: 12)
                .padding(.bottom, 3)

            Circle()
                .fill(foregroundColor)
                .frame(width: 6, height: 6)
                .padding(.bottom, 12)
        }
        .foregroundStyle(foregroundColor)
    }
}

struct VisualizerBar: View {
    let level: CGFloat
    let index: Int
    let foregroundColor: Color

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let barPhase = CGFloat(time) * 8 - CGFloat(index) * 0.7
            let wave = (sin(barPhase) * 0.3 + 0.7)

            let baseHeight: CGFloat = 4
            let audioHeight = level * 18
            let finalHeight = max(baseHeight, audioHeight * wave)

            RoundedRectangle(cornerRadius: 3)
                .fill(foregroundColor)
                .frame(width: 4, height: finalHeight)
        }
        .foregroundStyle(foregroundColor)
    }
}

#if os(macOS)
    import AppKit

    struct AppKitGlassHost: NSViewRepresentable {
        let content: AnyView
        let cornerRadius: CGFloat
        let tint: Color?
        let overlayOpacity: CGFloat
        let overlayColor: Color

        class Coordinator {
            var tintLayer: CALayer?
            var effectView: NSVisualEffectView?
            var hosting: NSHostingView<AnyView>?
        }

        func makeCoordinator() -> Coordinator { Coordinator() }

        func makeNSView(context: Context) -> NSView {
            // Container remains non-layer-backed to avoid breaking live blur
            let container = NSView(frame: .zero)
            container.translatesAutoresizingMaskIntoConstraints = false

            // Visual effect view for dependable live blur
            let effectView = NSVisualEffectView(frame: .zero)
            effectView.translatesAutoresizingMaskIntoConstraints = false
            effectView.material = .underWindowBackground
            effectView.blendingMode = .behindWindow
            effectView.state = .active
            effectView.wantsLayer = true
            effectView.layer?.cornerRadius = cornerRadius
            effectView.layer?.masksToBounds = true

            // Tint overlay CALayer that we can animate
            let tintLayer = CALayer()
            tintLayer.backgroundColor = NSColor(overlayColor).cgColor
            tintLayer.opacity = Float(overlayOpacity)
            tintLayer.cornerRadius = cornerRadius
            tintLayer.masksToBounds = true
            tintLayer.frame = effectView.bounds
            tintLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            effectView.layer?.addSublayer(tintLayer)

            // Host SwiftUI content above the effect background
            let hosting = NSHostingView(rootView: content)
            hosting.translatesAutoresizingMaskIntoConstraints = false
            effectView.addSubview(hosting)

            container.addSubview(effectView)

            // Constrain effect view to fill container
            NSLayoutConstraint.activate([
                effectView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                effectView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                effectView.topAnchor.constraint(equalTo: container.topAnchor),
                effectView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])

            // Constrain hosting view to fill effect view
            NSLayoutConstraint.activate([
                hosting.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
                hosting.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
                hosting.topAnchor.constraint(equalTo: effectView.topAnchor),
                hosting.bottomAnchor.constraint(equalTo: effectView.bottomAnchor),
            ])

            // Store references in context for updates
            context.coordinator.tintLayer = tintLayer
            context.coordinator.effectView = effectView
            context.coordinator.hosting = hosting

            return container
        }

        func updateNSView(_ container: NSView, context: Context) {
            guard let effectView = context.coordinator.effectView else { return }

            // Ensure effect is active and clipped
            effectView.material = .underWindowBackground
            effectView.blendingMode = .behindWindow
            effectView.state = .active
            effectView.wantsLayer = true
            effectView.layer?.cornerRadius = cornerRadius
            effectView.layer?.masksToBounds = true

            // Update hosted SwiftUI content
            if let hosting = context.coordinator.hosting {
                hosting.rootView = content
            }

            // Update tint overlay
            if let tintLayer = context.coordinator.tintLayer {
                tintLayer.opacity = Float(overlayOpacity)
                tintLayer.backgroundColor = NSColor(overlayColor).cgColor
                tintLayer.cornerRadius = cornerRadius
                tintLayer.masksToBounds = true
            }
        }
    }
#endif
