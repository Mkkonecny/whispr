import AppKit
import ApplicationServices
import SwiftUI

class RecordingWindow: NSPanel {
    private var repositionTimer: Timer?
    private var dockPollTimer: Timer?
    private var cachedDockHeight: CGFloat = 0
    private var targetDockHeight: CGFloat = 0
    private var hasAccessibilityPermission: Bool = false

    init(contentView: AnyView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 160, height: 60),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.isFloatingPanel = true
        // Use .floating (level 3) instead of .popUpMenu (level 101).
        // This keeps the bar below the Dock's window level (20),
        // so it doesn't interfere with the Dock's hover tracking.
        // The bar is positioned ABOVE the dock spatially (dockHeight + 20px gap),
        // so it's still fully visible.
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.backgroundColor = .clear
        self.hasShadow = false
        self.isOpaque = false
        self.ignoresMouseEvents = true

        let hostingView = NSHostingView(rootView: contentView)
        self.contentView = hostingView

        hasAccessibilityPermission = AXIsProcessTrusted()

        reposition(animated: false)

        // Dock height polling at ~30Hz
        startDockPolling()

        // Reposition at ~60Hz for smooth lerp animation
        repositionTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) {
            [weak self] _ in
            guard let self = self, self.isVisible else { return }
            self.smoothUpdateAndReposition()
        }
    }

    // MARK: - Smooth Interpolation

    private func smoothUpdateAndReposition() {
        let lerpFactor: CGFloat = 0.12
        let diff = targetDockHeight - cachedDockHeight

        if abs(diff) < 0.5 {
            cachedDockHeight = targetDockHeight
        } else {
            cachedDockHeight += diff * lerpFactor
        }

        reposition()
    }

    // MARK: - Dock Height Polling

    private func startDockPolling() {
        dockPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) {
            [weak self] _ in
            guard let self = self else { return }

            // Re-check permission periodically
            if !self.hasAccessibilityPermission {
                if AXIsProcessTrusted() {
                    DispatchQueue.main.async {
                        self.hasAccessibilityPermission = true
                        print("✅ Accessibility permission granted for Dock tracking")
                    }
                }
            }

            guard let screen = self.screen ?? NSScreen.main else { return }

            // Always account for permanently visible dock (auto-hide OFF)
            let permanentDockHeight = screen.visibleFrame.minY - screen.frame.minY

            if self.hasAccessibilityPermission {
                DispatchQueue.global(qos: .userInteractive).async {
                    let axHeight = self.fetchDockHeightViaAX(for: screen)
                    DispatchQueue.main.async {
                        // AX gives real-time height for both auto-hide and permanent dock
                        self.targetDockHeight = axHeight
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.targetDockHeight = max(permanentDockHeight, 0)
                }
            }
        }
    }

    // MARK: - AX-Based Dock Height Detection

    /// Uses AXPosition.y of the Dock's AXList child to determine visibility.
    /// When hidden: position.y == screenHeight (dock sits below screen).
    /// When visible: position.y < screenHeight (dock slides up).
    /// Visible height = screenHeight - position.y
    private func fetchDockHeightViaAX(for screen: NSScreen) -> CGFloat {
        let dockApps = NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.apple.dock")
        guard let dockApp = dockApps.first else { return 0 }

        let dockElement = AXUIElementCreateApplication(dockApp.processIdentifier)
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            dockElement, kAXChildrenAttribute as CFString, &value)
        guard result == .success, let children = value as? [AXUIElement] else { return 0 }

        let primaryScreenHeight = NSScreen.screens[0].frame.height
        let cgScreenBottom = primaryScreenHeight - screen.frame.minY

        for child in children {
            var pVal: CFTypeRef?
            var sVal: CFTypeRef?
            guard
                AXUIElementCopyAttributeValue(child, kAXPositionAttribute as CFString, &pVal)
                    == .success,
                AXUIElementCopyAttributeValue(child, kAXSizeAttribute as CFString, &sVal)
                    == .success
            else { continue }

            var position: CGPoint = .zero
            var size: CGSize = .zero
            AXValueGetValue(pVal as! AXValue, .cgPoint, &position)
            AXValueGetValue(sVal as! AXValue, .cgSize, &size)

            // Must be wide enough to be the dock bar
            guard size.width > 100 else { continue }

            // Visible height = how much of the dock is above screen bottom
            let visibleHeight = max(0, cgScreenBottom - position.y)
            return visibleHeight
        }

        return 0
    }

    // MARK: - Repositioning

    func reposition(animated: Bool = false) {
        let mouseLocation = NSEvent.mouseLocation
        let screens = NSScreen.screens

        let screen =
            screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
            ?? NSScreen.main
            ?? screens.first

        guard let screen = screen else { return }
        let fullFrame = screen.frame

        let targetWidth: CGFloat = 160
        let targetHeight: CGFloat = 60
        let x = fullFrame.minX + (fullFrame.width - targetWidth) / 2

        let gap: CGFloat = 10
        let y = fullFrame.minY + cachedDockHeight + gap

        let newFrame = NSRect(x: x, y: y, width: targetWidth, height: targetHeight)

        let deltaY = abs(newFrame.origin.y - self.frame.origin.y)
        let deltaX = abs(newFrame.origin.x - self.frame.origin.x)
        guard deltaY > 0.3 || deltaX > 0.3 else { return }

        self.setFrame(newFrame, display: true)
    }

    // MARK: - Show / Hide

    func show() {
        self.cachedDockHeight = self.targetDockHeight
        self.reposition(animated: false)
        self.makeKeyAndOrderFront(nil)
    }

    func hide() {
        self.orderOut(nil)
    }

    override var canBecomeKey: Bool { return false }

    deinit {
        repositionTimer?.invalidate()
        dockPollTimer?.invalidate()
    }
}
