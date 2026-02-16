import SwiftUI

struct RecordingBarView: View {
    @ObservedObject var audioManager: AudioCaptureManager

    // States for multi-stage size-based animation
    @State private var isShowingLogo = false
    @State private var isExpanded = false
    @State private var isVanishing = false

    private var normalizedLevel: CGFloat {
        let level = CGFloat(audioManager.audioLevel)
        return min(max(level * 60, 0.05), 1.0)
    }

    private let expansionThreshold: Float = 0.015

    var body: some View {
        ZStack {
            // Main stable container
            ZStack {
                // Background glass
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.12),
                                Color.white.opacity(0.04),
                                Color.white.opacity(0.08),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.4), lineWidth: 0.5)
                            .mask(
                                LinearGradient(
                                    colors: [.black, .clear], startPoint: .top, endPoint: .bottom))
                    )
                    .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)

                // Content Layer
                HStack(spacing: 12) {
                    // W Logo
                    ZStack {
                        LogoView()
                    }
                    .frame(width: 20)
                    .opacity(isShowingLogo ? 1 : 0)

                    // Visualizer
                    if isExpanded {
                        HStack(spacing: 3) {
                            ForEach(0..<7) { i in
                                VisualizerBar(level: normalizedLevel, index: i)
                            }
                        }
                        .transition(.scale(scale: 0.5, anchor: .leading).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, isExpanded ? 16 : 0)
            }
            // Transition logic: 'isVanishing' keeps the frame width (44px) stable
            // while 'isShowingLogo' fades the content and background.
            .frame(width: isExpanded ? 160 : (isShowingLogo || isVanishing ? 44 : 0), height: 44)
            .opacity(isShowingLogo ? 1 : 0)
            .scaleEffect(isShowingLogo ? 1.0 : 0.8)
            .frame(width: 160, alignment: .center)
            .background(
                Capsule()
                    .fill(Material.thinMaterial)
                    .opacity(isShowingLogo ? 0.5 : 0)
                    .frame(
                        width: isExpanded ? 160 : (isShowingLogo || isVanishing ? 44 : 0),
                        height: 44)
            )
        }
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
    }

    func startAnimationSequence() {
        isVanishing = false
        isShowingLogo = false
        isExpanded = false

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
            isShowingLogo = true
        }
    }

    func stopAnimationSequence() {
        // 1. Shrink full capsule back down to logo center
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85, blendDuration: 0)) {
            isExpanded = false
        }

        // 2. Persist Logo for 1.0 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // 3. Unified vanish: Logo and Container fade and scale out TOGETHER
            isVanishing = true  // Lock frame width
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
                isShowingLogo = false
            }

            // Cleanup vanishing state after animation completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isVanishing = false
            }
        }
    }
}

struct LogoView: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 1.5) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.85))
                .frame(width: 5, height: 18)
                .rotationEffect(.degrees(-5), anchor: .bottomTrailing)

            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.85))
                .frame(width: 5, height: 12)
                .padding(.bottom, 3)

            Circle()
                .fill(Color.black.opacity(0.85))
                .frame(width: 6, height: 6)
                .padding(.bottom, 12)
        }
    }
}

struct VisualizerBar: View {
    let level: CGFloat
    let index: Int

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let barPhase = CGFloat(time) * 8 - CGFloat(index) * 0.7
            let wave = (sin(barPhase) * 0.3 + 0.7)

            let baseHeight: CGFloat = 4
            let audioHeight = level * 18
            let finalHeight = max(baseHeight, audioHeight * wave)

            RoundedRectangle(cornerRadius: 3)
                .fill(Color.black.opacity(0.95))
                .frame(width: 4, height: finalHeight)
        }
    }
}
